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

- Translate transport errors into domain errors at the impl boundary. Catch `NetError`, inspect the status code, and throw the appropriate domain error (`AuthError.invalidCredentials`, etc.). Do not leak `NetError` to callers when a domain error exists.

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
// ❌ Leaking NetError to callers when a domain error exists
public func login(identifier: String, password: String) async throws -> LoginResult {
    let response: FreeAPIEnvelope<LoginDataDTO> = try await client.request(request)
    return LoginResult(…)
}
// A 401 reaches the feature as NetError.http(401, …), forcing UI to know about transport.

// ✅ Translate at the impl boundary
do {
    let response: FreeAPIEnvelope<LoginDataDTO> = try await client.request(request)
    return LoginResult(…)
} catch let error as NetError {
    if case let .http(status, _, _) = error, status == 401 || status == 400 {
        throw AuthError.invalidCredentials
    }
    throw AuthError.underlying(error)
}
```

## Non-goals

This skill does not cover:

- The contracts themselves (`*Repository` protocols, domain models, `*Error` enums) — those live in `Core` and are governed by `CLAUDE.md` → "How to add a contract".
- Transport-layer types (`AlamofireNetClient`, `AuthenticatedNetClient`, `TokenRefresher`) — those live in `Networking`.
- DI wiring of repos into the app — see `App/Sources/AppDependencies.swift`.
- UI feedback for repository errors — that is a feature concern.
