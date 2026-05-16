import Core
import Data
import Foundation
import Networking

struct AppDependencies {
    let pokemonRepository: any PokemonRepository

    static func live() -> AppDependencies {
        let netClient = AlamofireNetClient(userAgent: defaultUserAgent())
        return AppDependencies(
            pokemonRepository: PokemonRepositoryImpl(client: netClient)
        )
    }

    private static func defaultUserAgent() -> String {
        let os = ProcessInfo.processInfo.operatingSystemVersion
        let osVersion = "\(os.majorVersion).\(os.minorVersion)"
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        #if DEBUG
        let flavour = "debug"
        #else
        let flavour = "release"
        #endif
        return "iOS/\(osVersion) modular \(appVersion) (\(flavour))"
    }
}
