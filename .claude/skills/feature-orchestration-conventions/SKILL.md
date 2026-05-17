---
name: feature-orchestration-conventions
description: Decide whether a feature's UI should call repositories directly or go through a use-case-shaped facade (Session, Handler, etc.). Apply when creating a new feature, when a UIViewController/ViewModel needs to coordinate state or persistence beyond a single network call, when proposing or extending an `AuthSession`-like type, or when naming a new orchestration layer (debating suffixes like Session/Handler/Service/Manager/UseCase). Triggers on prompts about "use case", "session", "orchestrator", "facade between VC and repo", "should this VC use the repo directly", or on code that creates a file containing both a `*Repository` reference and observable state, broadcast, or persistence side effects.
---

# Feature orchestration conventions

A feature's UIKit code (`UIViewController`, future ViewModels) needs to reach data eventually. The question this skill answers: **does it call a `*Repository` from Core directly, or does it go through a use-case-shaped facade (`*Session`, `*Handler`, …)?** Both shapes already exist in the project — `Features/Pokemon` calls `PokemonRepository` directly, `Features/Account` goes through `AuthSession`. Pick the right one per feature, deliberately.

## The rule

Put a facade between the feature UI and the repositories **when at least one** of the following applies. If none apply, the VC takes the repository directly.

1. **Observable state that survives across calls.** Something the UI subscribes to. `AuthSession.authState` + `authStates()` is the case-in-point — multiple VCs swap children based on the same shared state.
2. **Coordination of multiple collaborators.** Several repos, repo + persistence, repo + cache, repo + clock. `AuthSession.login` coordinates `AccessRepository` + `TokenStore` + state mutation + broadcast in one atomic operation.
3. **Broadcast to multiple observers.** A single result that several places in the UI need to react to. `AuthSession.authStates()` does this via `AsyncStream`. If only one VC ever consumes the data, this criterion is not met.
4. **Side effects outside the repo's scope.** Persist tokens, invalidate caches, fire correlated telemetry, dismiss a sheet on a parent, mark something read. Anything the data layer can't and shouldn't know about.

If none of the four apply, the facade is dead weight — a passthrough that ages badly. Three months later nobody knows whether the indirection was "for consistency" or "for a reason I forgot," and edits get cargo-culted into both layers.

## Worked example from this project

| | `Pokemon` feature | `Account` feature |
|---|---|---|
| Observable state | none | `authState` + `authStates()` |
| Coordination | single repo | repo + Keychain + state + broadcast |
| Broadcast | single consumer | multiple potential consumers |
| Side effects | none | save/clear tokens, swap child VC |
| **Verdict** | `PokemonViewController` takes `any PokemonRepository` directly | `AccountViewController` takes `any AuthSession`, never `AccessRepository` |

If a Pokemon feature gains state later (favorites that need to sync, a "last-seen" cursor), the criteria flip and we add a `PokemonSession` (or similar) at that point. Not before.

## Naming the facade

The suffix encodes what the thing is, not just where it sits. Pick the one that matches the shape — do not default to `Service` or `Manager`.

| Suffix | Use when | Examples |
|---|---|---|
| **`Session`** | Tracks the lifetime/state of a "session" the user is in. Has state, observable. | `AuthSession`, hypothetical `RealtimeSession`, `PresenceSession`. |
| **`Handler`** | Reacts to external events without owning meaningful state. | Push notification arrival handler, deep-link handler, app-open URL handler. **Not** for things that hold state — that's a `Session`. |
| **`Coordinator`** | **Already reserved in this project for navigation.** Do not reuse for orchestration. |
| **`Service` / `Manager`** | Avoid. They mean nothing and absorb every concern that lacks a better name. If you find yourself reaching for these, the responsibility is probably not yet defined enough. |
| **`UseCase` / `Interactor`** (Clean Architecture style) | One class per operation (`LoginUseCase`, `LogoutUseCase`, …). Heavy ceremony. Not the project's style — we group related operations into a single session-shaped object. Do not introduce unless there's a specific reason. |

Diagnostic question when uncertain: *does this thing own state, or does it only react?* State → `Session`. Reaction-only → `Handler`. Neither → you probably don't need a facade.

## Where the facade lives (project layering)

The pattern matches what `AuthSession` already does:

- **Protocol** in `Core/Sources/<Domain>/`. `@MainActor` if the consumers are UI. The protocol is the *use-case* contract: methods named after what the feature does (`login`, `logout`, `refreshCurrentUser`), not after HTTP verbs.
- **Implementation** in `App/Sources/<Domain>/`. The impl is the only place that holds concrete repository references (`any *Repository`) and coordinates them. App is the composition root — this is where it belongs per `CLAUDE.md` → "Dependency rules".
- **Feature** depends only on `Core` + `SharedUI`. It takes `any <DomainSession>` (or `any *Repository` when no facade exists) by init. Never knows about Data, Networking, or the impl.

If you find yourself wanting to put the facade impl in `Data/` or in the feature itself, stop. `Data/` is for repository impls (data shape). The feature module is for UI. The facade is the use-case layer that lives between them — and the only module that depends on both is `App`.

## What goes inside the facade

A facade method is allowed (and expected) to:
- Call multiple repositories in sequence or in parallel.
- Persist/read from `TokenStore`-like protocols.
- Mutate its own observable state (`authState = …`) and broadcast.
- Translate repository errors into a user-facing domain error (`AuthError`).
- Apply policy that doesn't belong in the data layer (proactive refresh, retry, idempotence keys, throttling).

A facade method should NOT:
- Touch UIKit. `@MainActor` is for isolation, not for `UIViewController` references.
- Format strings for the UI. Strings are a feature concern.
- Make HTTP requests directly. Always go through a repository.

## Anti-patterns

```swift
// ❌ Passthrough facade — every method just forwards to the repo.
@MainActor
public protocol PokemonSession: AnyObject {
    func list() async throws -> [Pokemon]
    func detail(id: Int) async throws -> PokemonDetail
}

final class PokemonSessionImpl: PokemonSession {
    private let repo: any PokemonRepository
    func list() async throws -> [Pokemon] { try await repo.list(offset: 0, limit: 50) }
    func detail(id: Int) async throws -> PokemonDetail { try await repo.detail(id: id) }
}
// No state, no coordination, no broadcast, no side effects. Dead indirection.
// Verdict: the VC should hold `any PokemonRepository` directly.
```

```swift
// ❌ Repository calling the session — upward dependency.
public struct AccessRepositoryImpl: AccessRepository {
    private let session: any AuthSession   // ← wrong direction
    public func login(...) async throws(AuthError) -> LoginResult {
        let result = try await performHTTP()
        await session.setAuthenticated(result.user, tokens: result.tokens)  // ← repo doing state work
        return result
    }
}
// The repository now has a side effect outside transport.
// It cannot be reused in any flow that doesn't want to mutate the session
// (e.g. a "validate credentials without logging in" test path).
// Verdict: keep the repo dumb; the session orchestrates above it.
```

```swift
// ❌ Naming the orchestration layer "Manager" when it's a session.
final class AuthManager {                  // ← what does Manager mean?
    private(set) var state: AuthState
    func login(...) async throws { ... }
}
// Pick the suffix that says what the thing is.
// State + session lifetime → Session.
```

```swift
// ❌ Putting the facade impl in Data/.
// Data/Sources/Auth/AuthSessionImpl.swift
public struct AuthSessionImpl: AuthSession {
    // Has to import Networking, hold AccessRepositoryImpl directly, etc.
}
// Data is for transport-shaped repositories, not use-case-shaped orchestrators.
// Verdict: the facade impl lives in App/Sources/<Domain>/.
```

## When the criteria change later

Promote a feature from "VC + repo" to "VC + facade + repo" the moment the first criterion appears, not before. Concretely:
- A second consumer needs the same data live → broadcast → introduce a session with `AsyncStream`.
- A persistence layer is added (favorites in Keychain, last-seen cursor on disk) → coordination → introduce a session.
- An error mapping has to be reused by multiple VCs → side effects → introduce a session.

The reverse direction is rarer: if a `*Session` exists but no longer carries any of the four criteria (a refactor removed the state, the broadcast, etc.), collapse it back to the repo. Indirection without a current reason is debt.

## Non-goals

This skill does not cover:
- Repository conventions (DTOs, file split, base URL injection, error translation at the transport boundary). See `data-layer-conventions`.
- Navigation. Cross-screen and cross-feature transitions use `Coordinator` (see existing `AccountCoordinator`, `PokemonCoordinator`).
- Whether to introduce a ViewModel between the VC and the facade. Today the project uses VCs directly; if/when ViewModels appear, the facade pattern stays the same — the VM consumes `any AuthSession` instead of the VC doing it.
- Generic Clean Architecture / VIPER / TCA debates. The project chose UIKit + coordinator + session/repo. Don't litigate the choice; apply the rule.
