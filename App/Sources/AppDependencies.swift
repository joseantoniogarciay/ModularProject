import Core
import Data
import Foundation
import Networking
import SharedUI

@MainActor
struct AppDependencies {
    let pokemonRepository: any PokemonRepository
    let imageLoader: any ImageLoader

    static func live() -> AppDependencies {
        let netClient = AlamofireNetClient(userAgent: defaultUserAgent())
        return AppDependencies(
            pokemonRepository: PokemonRepositoryImpl(client: netClient),
            imageLoader: KingfisherImageLoader()
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
