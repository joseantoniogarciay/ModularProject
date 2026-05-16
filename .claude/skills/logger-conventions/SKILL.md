---
name: logger-conventions
description: Enforce this project's logging conventions whenever you write, edit, or extend logging code. Apply when the prompt or code touches `LogCenter`, `AppLogger`, `LogCategory`, `LogFormat`, `logMessage`, `OSLogAppLogger`, `PulseAppLogger`, the `Logging/` subfolders in `Core/` or `App/`, or imports `os.Logger` / `OSLog` / `Pulse` / `LoggerStore`. Also apply when the user asks to add a new logger, add a new log category, persist a log to disk, integrate analytics/observability, toggle logging at runtime, or send breadcrumbs/traces. The skill protects an unsafe-by-convention invariant on `LogCenter.loggers` and the layering between Core (protocol + entry point) and App (impls).
---

# Logging conventions

All logs in this project go through a single entry point: `logMessage(_:category:format:)` declared in `Core/Sources/Logging/Logging.swift`. The runtime impls (`OSLogAppLogger`, `PulseAppLogger`) live in `App/Sources/Logging/` and are gated by `#if DEV`. Reaching for `os.Logger` directly, calling `print(...)` for diagnostics, persisting logs manually, or registering loggers outside the App layer are all defects — fix before the change lands.

## What's available

### Core (the contract)

- `LogCategory` enum: `.net`, `.viewCycle`, `.breadcrumbs`. **Closed set.** Adding a case forces touching every `AppLogger` impl, so do not add one speculatively.
- `LogFormat` enum: `.info`, `.error`.
- `protocol AppLogger: Sendable` with `func log(_ message: String, category: LogCategory, format: LogFormat)`.
- `enum LogCenter` exposing `nonisolated(unsafe) public static var loggers: [any AppLogger]`.
- `func logMessage(_ message: String, category: LogCategory, format: LogFormat = .info)` — the only API consumers should call.

### App (the impls)

- `App/Sources/Logging/OSLogAppLogger.swift` (`#if DEV`): per-category `os.Logger` instances under subsystem `com.modular.app`.
- `App/Sources/Logging/PulseAppLogger.swift` (`#if DEV`): forwards non-net entries to `LoggerStore.shared.storeMessage(...)`. Filters `.net` itself because Pulse's `URLSessionProxyDelegate` already captures the wire traffic.
- `AppDelegate.application(_:didFinishLaunchingWithOptions:)` inside `#if DEV`:

  ```swift
  LogCenter.loggers = [OSLogAppLogger(), PulseAppLogger()]
  URLSessionProxyDelegate.enableAutomaticRegistration()
  ```

## Rules

### DO

- Call `logMessage(_:category:format:)` from any module that needs to emit a log entry.
- Pick the closest existing category. Network traffic → `.net`. View lifecycle (viewDidLoad, viewDidAppear, etc.) → `.viewCycle`. Free-form breadcrumb traces or generic diagnostics → `.breadcrumbs`.
- When adding a new `AppLogger` impl, place it in `App/Sources/Logging/`, wrap it in `#if DEV` (or another deliberate gate), and register it inside `AppDelegate.application(_:didFinishLaunchingWithOptions:)` next to the existing ones. Do not lazy-register at first use, do not register from a feature.

### DO NOT

- **Never mutate `LogCenter.loggers` outside `AppDelegate.application(_:didFinishLaunchingWithOptions:)`.** The array is `nonisolated(unsafe)`. It is correct only because it is written exactly once on the main thread at launch, before any reader can run on a different thread. Mutating it from a `Task`, a closure, an actor, an `async` flow, or a feature-flag callback is undefined behavior — concurrent reads can crash on use-after-free or see a corrupted array. If runtime mutation is genuinely required, see the next section ("If you need runtime mutation").

- **Never call `os.Logger` (or any `Logger.info`/`Logger.error` directly) outside an `AppLogger` impl.** Features, UseCases, Data, Networking, SharedUI must go through `logMessage()`. Direct OSLog calls bypass the runtime gating between AppDev and App-prod, end up in production logs that should not exist, and skip the Pulse mirror.

- **Never use `print(...)` for logging.** It does not respect the dev/prod gate, it always prints in App-prod, and it cannot be filtered. If you want a quick trace during development, use `logMessage("...", category: .breadcrumbs)`.

- **Do not register loggers from any module other than `App`.** `Core`, `Networking`, `Data`, `SharedUI`, and any feature module must not touch `LogCenter.loggers`.

- **Do not add a `LogCategory` case speculatively.** Each case must have a real, current call site at the time it is introduced. Speculative cases rot and force every impl to handle dead branches.

- **Do not weaken Pulse's `.net` skip in `PulseAppLogger`.** Pulse already captures network traffic via `URLSessionProxyDelegate.enableAutomaticRegistration()`. Removing the `guard category != .net` would produce duplicate entries in the console.

## If you need runtime mutation of the logger set

If a feature genuinely needs to add or remove loggers after launch (experiment toggle, runtime kill switch, configuration push), the `nonisolated(unsafe)` storage is no longer safe. **Refactor first, mutate second** — never the other way around.

The replacement:

```swift
public final class LogCenter: @unchecked Sendable {
    public static let shared = LogCenter()
    private let lock = OSAllocatedUnfairLock(initialState: [any AppLogger]())

    public var loggers: [any AppLogger] {
        lock.withLock { $0 }
    }

    public func setLoggers(_ loggers: [any AppLogger]) {
        lock.withLock { $0 = loggers }
    }

    public func append(_ logger: any AppLogger) {
        lock.withLock { $0.append(logger) }
    }
}
```

`OSAllocatedUnfairLock` is iOS 16+ (matches the deployment target). Lock cost is in the tens of nanoseconds per call. `logMessage` stays synchronous; no `async` contagion.

Land the refactor — including updating `logMessage` to read via `LogCenter.shared.loggers` and `AppDelegate` to call `LogCenter.shared.setLoggers(...)` — in its own commit. Only then introduce the runtime mutation.

## Anti-patterns and fixes

```swift
// ❌ Bypassing logMessage to log directly from a feature
import OSLog
private let logger = Logger(subsystem: "com.modular.app", category: "pokemon")
logger.info("Loaded \(pokemons.count) pokemons")

// ✅ Use the project entry point
import Core
logMessage("Loaded \(pokemons.count) pokemons", category: .breadcrumbs)
```

```swift
// ❌ Mutating LogCenter.loggers after launch
Task {
    if await featureFlags.isPulseEnabled() {
        LogCenter.loggers.append(PulseAppLogger())
    }
}

// ✅ Either decide the set at launch, or refactor LogCenter to lock-based first
```

```swift
// ❌ print() for development trace
print("⚠️ network error: \(error)")

// ✅ Use the appropriate category and format
logMessage("network error: \(error)", category: .net, format: .error)
```

```swift
// ❌ Adding a category without a call site
public enum LogCategory: String, Sendable {
    case net
    case viewCycle
    case breadcrumbs
    case analytics  // ← speculative, no consumer
}

// ✅ Wait until a real call site needs it, then add together
```

## Non-goals

This skill does not cover:

- General `os.Logger` patterns (privacy markers, log levels semantics, etc.) — Apple's docs are the source.
- The `App-Develop` vs `App-Prod` target split or the `DEV` compilation condition — see `CLAUDE.md` → "Dependency rules" and the App entry.
- Generic Sendable / strict concurrency guidance — see `CLAUDE.md` and the `swift-concurrency` skill.
- Pulse's `ConsoleView` viewer or the shake gesture — those live in `App/Sources/Extensions/` and are presentation concerns, not logging conventions.
