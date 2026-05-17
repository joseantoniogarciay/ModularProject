import Core
import Data
import Foundation
import Networking
import SharedUI

@MainActor
struct AppDependencies {
    let pokemonRepository: any PokemonRepository
    let imageLoader: any ImageLoader
    let authSession: any AuthSession

    static func live(configuration: AppConfiguration = .live()) -> AppDependencies {
        let userAgent = defaultUserAgent()
        let pokemonClient = AlamofireNetClient(userAgent: userAgent)

        let unauthenticatedClient = AlamofireNetClient(userAgent: userAgent)
        let tokenStore = KeychainTokenStore()
        let authRepository = AuthRepositoryImpl(
            client: unauthenticatedClient,
            baseURL: configuration.freeAPIBaseURL
        )
        let refresher = TokenRefresher(tokenStore: tokenStore, authRepository: authRepository)
        let authenticatedClient = AuthenticatedNetClient(base: unauthenticatedClient, refresher: refresher)
        let userRepository = UserRepositoryImpl(
            client: authenticatedClient,
            baseURL: configuration.freeAPIBaseURL
        )
        let authSession = AuthSessionImpl(
            tokenStore: tokenStore,
            authRepository: authRepository,
            userRepository: userRepository
        )

        return AppDependencies(
            pokemonRepository: PokemonRepositoryImpl(
                client: pokemonClient,
                baseURL: configuration.pokeAPIBaseURL
            ),
            imageLoader: KingfisherImageLoader(),
            authSession: authSession
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
