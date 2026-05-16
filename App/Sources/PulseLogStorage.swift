#if DEV
import Core
import Foundation
import Pulse

struct PulseLogStorage: LogStorage {
    func store(category: LogCategory, format: LogFormat, message: String) {
        let level: LoggerStore.Level
        switch format {
        case .info: level = .info
        case .error: level = .error
        }
        LoggerStore.shared.storeMessage(label: category.rawValue, level: level, message: message)
    }
}
#endif
