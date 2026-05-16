import Foundation
import OSLog

extension Logger {
    private static let subsystem: String = "com.modular.app"

    static let net = Logger(subsystem: subsystem, category: "net")
    static let viewCycle = Logger(subsystem: subsystem, category: "viewCycle")
    static let statistics = Logger(subsystem: subsystem, category: "statistics")
    static let breadcrumbs = Logger(subsystem: subsystem, category: "breadcrumbs")
}
