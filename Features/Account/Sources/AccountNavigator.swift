import Foundation

@MainActor
protocol AccountNavigator: AnyObject {
    func accountDidRequestRegister()
}
