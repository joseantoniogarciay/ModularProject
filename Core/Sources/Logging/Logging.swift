import Foundation
import OSLog

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

public protocol LogStorage: Sendable {
    func store(category: LogCategory, format: LogFormat, message: String)
}

public enum LogCenter {
    // Invariant: written once during App bootstrap (on the main thread, before any
    // background thread can read it). After bootstrap the value is effectively
    // immutable, so unsynchronized reads from logMessage are safe.
    // Removal plan: switch to `Atomic` from the Synchronization module when the
    // deployment target reaches iOS 18.
    nonisolated(unsafe) public static var storage: (any LogStorage)?
}

public func logMessage(
    _ message: String,
    category: LogCategory,
    format: LogFormat = .info
) {
    #if DEV || DEBUG
    let logger: Logger
    switch category {
    case .net: logger = .net
    case .viewCycle: logger = .viewCycle
    case .statistics: logger = .statistics
    case .breadcrumbs: logger = .breadcrumbs
    }
    switch format {
    case .info:
        logger.info("\(message, privacy: .public)")
    case .error:
        logger.error("\(message, privacy: .public)")
    }
    if category != .net {
        LogCenter.storage?.store(category: category, format: format, message: message)
    }
    #endif
}
