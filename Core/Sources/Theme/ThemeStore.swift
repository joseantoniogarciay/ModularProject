public protocol ThemeStore {
    var current: ThemePreference { get }
    func set(_ preference: ThemePreference)
}
