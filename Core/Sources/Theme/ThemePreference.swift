public enum ThemePreference: String, Sendable {
    case system
    case light
    case dark

    public var next: ThemePreference {
        switch self {
        case .system: return .light
        case .light: return .dark
        case .dark: return .system
        }
    }
}
