import Foundation

public enum LogCategory: String, Sendable {
    case net
    case viewCycle
    case breadcrumbs
}

public enum LogFormat: Sendable {
    case info
    case error
}

public protocol AppLogger: Sendable {
    func log(_ message: String, category: LogCategory, format: LogFormat)
}

public enum LogCenter {
    // Invariant: written once during App bootstrap (on the main thread, before any
    // background thread can read it). After bootstrap the value is effectively
    // immutable, so unsynchronized reads from logMessage are safe.
    // Removal plan: switch to `Atomic` from the Synchronization module when the
    // deployment target reaches iOS 18.
    nonisolated(unsafe) public static var loggers: [any AppLogger] = []
}

public func logMessage(
    _ message: String,
    category: LogCategory,
    format: LogFormat = .info
) {
    for logger in LogCenter.loggers {
        logger.log(message, category: category, format: format)
    }
}
