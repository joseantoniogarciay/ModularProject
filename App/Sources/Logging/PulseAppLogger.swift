#if DEV
import Core
import Foundation
import Pulse

struct PulseAppLogger: AppLogger {
    func log(_ message: String, category: LogCategory, format: LogFormat) {
        // Net requests are captured by Pulse's URLSession proxy automatically;
        // don't double-log them through the message store.
        guard category != .net else { return }
        let level: LoggerStore.Level
        switch format {
        case .info: level = .info
        case .error: level = .error
        }
        LoggerStore.shared.storeMessage(label: category.rawValue, level: level, message: message)
    }
}
#endif
