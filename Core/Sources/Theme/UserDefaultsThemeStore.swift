import Foundation

public struct UserDefaultsThemeStore: ThemeStore {
    private static let key = "com.modular.themePreference"

    public init() {}

    public var current: ThemePreference {
        guard let raw = UserDefaults.standard.string(forKey: Self.key),
              let preference = ThemePreference(rawValue: raw) else { return .system }
        return preference
    }

    public func set(_ preference: ThemePreference) {
        UserDefaults.standard.set(preference.rawValue, forKey: Self.key)
    }
}
