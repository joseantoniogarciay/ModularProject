---
name: data-layer-conventions
description: Enforce this project's Data layer conventions whenever you create, edit, or extend code under `Data/Sources/`. Apply when writing or modifying DTOs (`Decodable`/`Encodable` structs that map an HTTP payload), repository implementations (`*RepositoryImpl`), domain-mapping `toDomain()` extensions, or any file that decodes a JSON response from an external API. Also apply when the user asks to add a new endpoint, a new repository, a new feature that needs network-backed data, or to refactor existing DTOs. The skill protects the file-per-use-case split for DTOs, the DTO→domain mapping boundary, and the layering between Core (contracts), Networking (transport), and Data (concrete impls).
---

# Data layer conventions

The `Data` module holds the concrete implementations of the `*Repository` protocols declared in `Core`, plus the DTOs that bridge wire formats to the domain models. Everything in `Data/Sources/` follows the rules below — deviations are defects, not style.

## Folder layout

```
Data/Sources/
└── <Domain>/                 # one folder per domain (Pokemon, Access, User, …)
    ├── <Endpoint>DTO.swift    # one file per use case (see "DTO file split")
    ├── …
    ├── <Domain>RepositoryImpl.swift
    └── (optional) <SharedEnvelope>.swift
```

`<Domain>` mirrors `Core/Sources/<Domain>/`. Domain names match the bounded contracts, not generic umbrellas — e.g. `Access/` (login, register, refresh, tokens) and `User/` (identity) are separate folders both in `Core` and `Data`, not bundled into a single `Auth/`. If you find yourself wanting an umbrella folder ("Auth" with both access and identity concerns), that is the smell — split it.

## DTO file split — THE rule

**One file per use case.** A "use case" is a single endpoint or a tightly-coupled request/response pair. DTOs that serve unrelated endpoints belong in different files, even when they share a domain folder.

### What goes together in a file

- The request body and the response payload for a single endpoint, when both exist (`LoginRequestBody` + `LoginDataDTO` → `LoginDTO.swift`).
- Auxiliary types that only that endpoint uses and that have no reuse elsewhere — keep them in the same file.
- A `toDomain()` extension belongs in the same file as the DTO it converts.

### What does NOT go together

- DTOs for different endpoints, even if they live under the same domain. Login, register, refresh, and current-user are four different use cases → four files.
- A DTO that is reused by multiple endpoints (e.g. `UserDTO` appears inside login, register, and current-user responses). Promote it to its own file (`UserDTO.swift`) and let the others depend on it.
- A shared envelope wrapper (e.g. `FreeAPIEnvelope<Payload>`) that wraps every response of an API. Own file (`<APIName>Envelope.swift`).

### Naming

- Use-case files: `<UseCase>DTO.swift` (`LoginDTO.swift`, `RegisterDTO.swift`, `RefreshTokenDTO.swift`).
- Shared model files: `<TypeName>.swift` (`UserDTO.swift`, `PokemonListDTO.swift`).
- Shared envelope: `<APIName>Envelope.swift` (`FreeAPIEnvelope.swift`).

### Worked example

```
Data/Sources/
├── FreeAPI/
│   └── FreeAPIEnvelope.swift             # shared response wrapper for any FreeAPI domain
├── Access/
│   ├── LoginDTO.swift                    # LoginRequestBody + LoginDataDTO
│   ├── RegisterDTO.swift                 # RegisterRequestBody + RegisterDataDTO
│   ├── RefreshTokenDTO.swift             # RefreshRequestBody + RefreshDataDTO
│   ├── AccessRepositoryImpl.swift        # login + register
│   └── AccessTokenRefreshingImpl.swift   # refresh
└── User/
    ├── UserDTO.swift                     # UserDTO + AvatarDTO + toDomain()
    └── UserRepositoryImpl.swift          # current-user
```

The shared envelope lives in `Data/Sources/<APIName>/` (e.g. `FreeAPI/`), not inside a domain folder. It is API-shaped, not domain-shaped — multiple domains under the same API consume it. Keeping it in one domain folder forces other domains to reach across folders, which is exactly the layering smell to avoid.

A single `AuthDTOs.swift` containing all of the above is a defect — split it. Likewise, a single `Auth/` folder mixing access-flow files and identity files is the same defect at folder granularity — split it.

## DTO type rules

- DTOs are `internal` by default. They never cross module boundaries: the public surface is the domain model from `Core`. Mark `public` only when there is a specific consumer in another module that justifies it.
- DTOs are `Decodable`/`Encodable` and `Sendable`. `Sendable` is required by the existing `NetClient` API (`request<T: Decodable & Sendable>(...)`).
- API field names that violate Swift naming (`_id`, snake_case) are mapped via a `private enum CodingKeys: String, CodingKey { … }`. Do not name a property `_id` to match the wire — SwiftLint's `identifier_name` rule rejects it, and the rename keeps the domain side clean.
- A DTO that converts to a `Core` domain type owns a `toDomain() -> DomainType` extension (or `toDomain() -> DomainType?` if the wire shape can be invalid; see `PokemonListItemDTO.toDomain()`). The extension lives in the same file as the DTO.
- Domain types live in `Core/Sources/<Domain>/`, are `public`, and are `Sendable`. DTOs never leak into other modules — only the domain model does.

## Repository impl rules

- File name: `<Domain>RepositoryImpl.swift` (or `<Concept>RepositoryImpl.swift` if the protocol is concept-scoped, e.g. `UserRepositoryImpl` for `UserRepository`).
- The impl is `public struct <Name>: <Protocol>` and conforms to a protocol declared in `Core`.
- Init injects the `NetClient` and the `baseURL: URL`. The base URL is passed in (it comes from `AppDependencies` / `AppConfiguration`) — never hardcode it in the impl.
- Build requests with `NetRequest.Builder()` directly. Do not create a per-feature request DSL on top of it.
- Decode with `client.request(_:)`. If the wire response is wrapped in an envelope, decode the envelope and project the `data` field:

  ```swift
  let response: FreeAPIEnvelope<LoginDataDTO> = try await client.request(request)
  return LoginResult(user: response.data.user.toDomain(), tokens: …)
  ```

- Translate transport errors into typed domain errors at the impl boundary. Do not leak `NetError` to callers — see "Repository errors" below for the shape and mapping pattern.

## Repository errors

**One error type per repository method.** Each method on a `*Repository` is a single use case (a single endpoint); each use case owns its own error enum so that the error space exposed at the call site is exactly the one this endpoint can produce — nothing more, nothing less.

### Where it lives

The error enum lives in `Core/Sources/<Domain>/<UseCase>Error.swift`, next to the protocol that throws it. It is `public`, `Error`, and `Sendable`. The Data impl never declares its own error type — it throws the one declared in the protocol.

### Shape

Every per-use-case error has three layers, in order:

1. `case noConnection` — transport-level signal mapped from `NetError.noConnection`. The UI uses this to show a "check your connection" affordance, so every networked use case has it.
2. Semantic cases this endpoint can legitimately return (`.invalidCredentials`, `.usernameOrEmailTaken`, `.notFound`, …). One case per distinct outcome the call site needs to branch on. Do not add cases that this endpoint cannot produce.
3. `case unknown(any Error)` — fallback for anything else. Carries the underlying error so logs/breadcrumbs keep the cause. The UI treats this as a generic failure.

```swift
// Core/Sources/Access/LoginError.swift
public enum LoginError: Error, Sendable {
    case noConnection
    case invalidCredentials
    case unknown(any Error)
}

// Core/Sources/Access/RegisterError.swift
public enum RegisterError: Error, Sendable {
    case noConnection
    case usernameOrEmailTaken
    case unknown(any Error)
}
```

### Protocol signature

The protocol declares the error with **typed throws** (see also `feedback-typed-throws` memory):

```swift
public protocol AccessRepository: Sendable {
    func login(identifier: String, password: String) async throws(LoginError) -> LoginResult
    func register(username: String, email: String, password: String) async throws(RegisterError) -> User
}
```

### Mapping in the impl

The impl translates `NetError` (and anything else) into the typed error at the method boundary. The pattern is uniform — typed catch for `NetError`, bare catch for everything else, both funneling non-mapped cases into `.unknown(error)` so the cause survives:

```swift
public func login(identifier: String, password: String) async throws(LoginError) -> LoginResult {
    let request = /* … */
    do {
        let response: FreeAPIEnvelope<LoginDataDTO> = try await client.request(request)
        return LoginResult(/* … */)
    } catch let error as NetError {
        if case .noConnection = error { throw .noConnection }
        if case let .http(status, _, _) = error, status == 401 || status == 400 {
            throw .invalidCredentials
        }
        throw .unknown(error)
    } catch {
        throw .unknown(error)
    }
}
```

### Why per use case, not per repository

Bundling multiple endpoints' errors into one type is the smell to avoid:

```swift
// ❌ One AuthError covers login + register + refresh.
public enum AuthError: Error, Sendable {
    case noConnection
    case invalidCredentials      // login only
    case usernameOrEmailTaken    // register only
    case refreshFailed           // refresh only
    case unknown(any Error)
}
```

`usernameOrEmailTaken` cannot happen on login, but the consumer of `login` is forced to handle (or default-away) a case that doesn't apply. The compiler can't help. The fix is one type per method — `LoginError` does not contain `usernameOrEmailTaken` because the endpoint cannot produce it.

### Consumer side

The feature catches the typed error and switches exhaustively over its cases. The catch is plain `catch { ... }` — Swift binds `error` to the typed error type automatically thanks to the protocol's typed throws (see [[feedback-typed-throws]] memory). Writing `catch let error as LoginError` is a redundant downcast and Swift warns `'as' test is always true`.

```swift
private func performLogin(id: String, password: String) async {
    do {
        let result = try await accessRepository.login(identifier: id, password: password)
        handleSuccess(result)
    } catch {
        switch error {                                     // error: LoginError
        case .noConnection:        show(CoreStrings.errorNoConnection)
        case .invalidCredentials:  show(CoreStrings.errorInvalidCredentials)
        case .unknown(let cause):  log(cause); show(CoreStrings.errorGeneric)
        }
    }
}
```

Adding a new semantic case to the error breaks the call sites that don't handle it — which is the point of typed throws.

**Important — keep the `do/catch` in a `func ... async`, not in a `Task { ... }` closure literal.** `Task.init`'s closure parameter is `() async throws -> T` (untyped), and per SE-0413 the closure body's effective throw type widens to `any Error` on conversion — typed inference is lost and a plain `catch` binds `error` to `any Error`, not the use-case error. Move the work to a method (`func performLogin(...) async`) and invoke it as `loadTask = Task { await self.performLogin(...) }`. See [[feedback-typed-throws]] for the full rationale.

### Composite errors for orchestrated use cases

When a *facade* method (a `*Session`/`*Handler`, see `feature-orchestration-conventions`) chains multiple repository calls, the facade owns its own composite error — not the repo. The composite can model failure modes that don't exist at any single endpoint (e.g. `autoLoginFailed` when register-then-login fails at the login step). The per-endpoint errors in this skill stay narrow; the composite is layered on top by the orchestrator and lives next to the facade protocol.

## URL composition

Build request URLs **one segment per `appendingPathComponent` call**. The argument must be a single path segment — no `/` inside it.

```swift
// ❌ Multi-segment string passed as one component
.url(baseURL.appendingPathComponent("users/login").absoluteString)
.url(baseURL.appendingPathComponent("users/current-user").absoluteString)

// ✅ One segment per call
.url(
    baseURL
        .appendingPathComponent("users")
        .appendingPathComponent("login")
        .absoluteString
)
```

It happens to work — `URL` treats the `/` inside the string as a path separator — but it's the same operation expressed two ways inside the same module, and the multi-segment form is the one that loses. The per-segment form also degrades gracefully if a future segment is a dynamic value: a stray `/` in a user-supplied identifier passed to `appendingPathComponent` is percent-encoded when it's its own call, but silently treated as a separator when it's spliced into a literal — that asymmetry is exactly the kind of bug to avoid by being uniform now.

Dynamic segments (IDs, slugs) are interpolated into their own call:

```swift
.url(
    baseURL
        .appendingPathComponent("pokemon")
        .appendingPathComponent("\(id)")
        .absoluteString
)
```

Query parameters use the builder's `queryItem(name:value:)` — never concatenate them into the URL string.

## Imports — minimal set

Data files import only what they use. The frequent mistakes:

- `NetClient`, `NetRequest`, `NetError`, `NetworkResponse`, `FormData` all live in **`Core`**, not `Networking`. A repository impl that only uses these types imports `Core` only — **no `import Networking`**.
- The `Networking` import is needed only when the file references a type that lives in `Networking/Sources/` (e.g. `AlamofireNetClient`, `AuthenticatedNetClient`, `TokenRefresher`). Repository impls almost never need it.
- DTO files import `Core` only when they reference a `Core` type (e.g. inside `toDomain()`). A pure DTO file with no domain mapping imports only `Foundation`.

If you find an unused `import Networking` in a Data file, remove it.

## Dependency rule (reminder)

`Data` depends on `Core` and `Networking` (declared in `Data/Project.swift`). It must not depend on `SharedUI`, any feature, or `App`. DTOs are an implementation detail of `Data`; they never appear in any other module's API.

## Anti-patterns and fixes

```swift
// ❌ Many unrelated DTOs in one file
// Data/Sources/Auth/AuthDTOs.swift
struct FreeAPIEnvelope<P: Decodable & Sendable>: …
struct UserDTO: Decodable, Sendable { … }
struct LoginRequestBody: Encodable, Sendable { … }
struct LoginDataDTO: Decodable, Sendable { … }
struct RegisterRequestBody: Encodable, Sendable { … }
struct RegisterDataDTO: Decodable, Sendable { … }
struct RefreshRequestBody: Encodable, Sendable { … }
struct RefreshDataDTO: Decodable, Sendable { … }

// ✅ One file per use case
// FreeAPIEnvelope.swift, UserDTO.swift, LoginDTO.swift, RegisterDTO.swift, RefreshTokenDTO.swift
```

```swift
// ❌ Property named to match the wire — SwiftLint rejects `_id`
struct UserDTO: Decodable, Sendable {
    let _id: String
    let username: String
}

// ✅ CodingKeys map the wire field to a Swift-clean property
struct UserDTO: Decodable, Sendable {
    let id: String
    let username: String

    private enum CodingKeys: String, CodingKey {
        case id = "_id"
        case username
    }
}
```

```swift
// ❌ Importing Networking when only Core types are used
import Core
import Foundation
import Networking   // ← unused

public struct AuthRepositoryImpl: AuthRepository {
    private let client: any NetClient   // NetClient is in Core
    …
}

// ✅ Drop the unused import
import Core
import Foundation
```

```swift
// ❌ Hardcoded base URL inside the impl
public struct AuthRepositoryImpl: AuthRepository {
    private let client: any NetClient
    private let baseURL = URL(string: "https://api.freeapi.app/api/v1")!
    …
}

// ✅ Inject the base URL — it comes from AppConfiguration / Info.plist
public struct AuthRepositoryImpl: AuthRepository {
    private let client: any NetClient
    private let baseURL: URL

    public init(client: any NetClient, baseURL: URL) {
        self.client = client
        self.baseURL = baseURL
    }
}
```

```swift
// ❌ Untyped throws — NetError leaks to the feature
public func login(identifier: String, password: String) async throws -> LoginResult {
    let response: FreeAPIEnvelope<LoginDataDTO> = try await client.request(request)
    return LoginResult(…)
}
// A 401 reaches the feature as NetError.http(401, …), forcing UI to know about transport.

// ✅ Typed throws with a per-use-case error, mapped at the impl boundary
public func login(identifier: String, password: String) async throws(LoginError) -> LoginResult {
    do {
        let response: FreeAPIEnvelope<LoginDataDTO> = try await client.request(request)
        return LoginResult(…)
    } catch let error as NetError {
        if case .noConnection = error { throw .noConnection }
        if case let .http(status, _, _) = error, status == 401 || status == 400 {
            throw .invalidCredentials
        }
        throw .unknown(error)
    } catch {
        throw .unknown(error)
    }
}
```

## Non-goals

This skill does not cover:

- The `*Repository` protocols and domain model types — those live in `Core` and are governed by `CLAUDE.md` → "How to add a contract". (Per-use-case `*Error` enums also live in `Core` but their shape **is** governed by this skill — see "Repository errors".)
- Transport-layer types (`AlamofireNetClient`, `AuthenticatedNetClient`, `TokenRefresher`) — those live in `Networking`.
- DI wiring of repos into the app — see `App/Sources/AppDependencies.swift`.
- UI feedback for repository errors — that is a feature concern.
