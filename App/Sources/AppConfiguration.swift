import Foundation

struct AppConfiguration: Sendable {
    let pokeAPIBaseURL: URL
    let freeAPIBaseURL: URL

    static func live(bundle: Bundle = .main) -> AppConfiguration {
        AppConfiguration(
            pokeAPIBaseURL: url(forKey: "PokeAPIBaseURL", in: bundle),
            freeAPIBaseURL: url(forKey: "FreeAPIBaseURL", in: bundle)
        )
    }

    private static func url(forKey key: String, in bundle: Bundle) -> URL {
        guard let string = bundle.object(forInfoDictionaryKey: key) as? String,
              let url = URL(string: string) else {
            preconditionFailure("Missing or invalid Info.plist entry for key '\(key)'")
        }
        return url
    }
}
