import Foundation

public enum LogCategory: String, Sendable {
    case net
    case viewCycle
    case statistics
    case breadcrumbs
}

public enum LogFormat: Sendable {
    case info
    case error
}

public protocol LogBackend: Sendable {
    func log(_ message: String, category: LogCategory, format: LogFormat)
}

public protocol LogStorage: Sendable {
    func store(category: LogCategory, format: LogFormat, message: String)
}

public enum LogCenter {
    // Invariant: written once during App bootstrap (on the main thread, before any
    // background thread can read it). After bootstrap the values are effectively
    // immutable, so unsynchronized reads from logMessage are safe.
    // Removal plan: switch to `Atomic` from the Synchronization module when the
    // deployment target reaches iOS 18.
    nonisolated(unsafe) public static var backend: (any LogBackend)?
    nonisolated(unsafe) public static var storage: (any LogStorage)?
}

public func logMessage(
    _ message: String,
    category: LogCategory,
    format: LogFormat = .info
) {
    LogCenter.backend?.log(message, category: category, format: format)
    if category != .net {
        LogCenter.storage?.store(category: category, format: format, message: message)
    }
}
