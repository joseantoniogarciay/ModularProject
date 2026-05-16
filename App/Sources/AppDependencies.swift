import Core
import Data
import Foundation
import Networking
import Pokemon

struct AppDependencies {
    let makeListPokemonUseCase: @Sendable () -> any ListPokemonUseCase
    let getPokemonDetailUseCase: any GetPokemonDetailUseCase

    static func live() -> AppDependencies {
        let netClient = AlamofireNetClient(userAgent: defaultUserAgent())
        let pokemonRepository = PokemonRepositoryImpl(client: netClient)
        return AppDependencies(
            makeListPokemonUseCase: {
                ListPokemonUseCaseImpl(repository: pokemonRepository)
            },
            getPokemonDetailUseCase: GetPokemonDetailUseCaseImpl(repository: pokemonRepository)
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
