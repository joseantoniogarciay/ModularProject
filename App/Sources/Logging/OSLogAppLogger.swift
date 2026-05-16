#if DEV
import Core
import Foundation
import OSLog

extension Logger {
    private static let subsystem: String = "com.modular.app"

    static let net = Logger(subsystem: subsystem, category: "net")
    static let viewCycle = Logger(subsystem: subsystem, category: "viewCycle")
    static let breadcrumbs = Logger(subsystem: subsystem, category: "breadcrumbs")
}

struct OSLogAppLogger: AppLogger {
    func log(_ message: String, category: LogCategory, format: LogFormat) {
        let logger: Logger
        switch category {
        case .net: logger = .net
        case .viewCycle: logger = .viewCycle
        case .breadcrumbs: logger = .breadcrumbs
        }
        switch format {
        case .info:
            logger.info("\(message, privacy: .public)")
        case .error:
            logger.error("\(message, privacy: .public)")
        }
    }
}
#endif
