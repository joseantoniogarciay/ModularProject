import Core
import Foundation
import Pokemon
import UIKit
import UserNotifications

@MainActor
final class PushNotificationRouter: NSObject {
    private let dependencies: AppDependencies

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }

    private func presentPokemonDetail(id: Int) {
        let imageURL = URL(string: "https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/\(id).png")
        let pokemon = Pokemon(id: id, name: "", imageURL: imageURL)
        let detailVC = PokemonDetailViewController(
            repository: dependencies.pokemonRepository,
            pokemon: pokemon,
            imageLoader: dependencies.imageLoader
        )
        detailVC.navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .close,
            target: self,
            action: #selector(closeTapped)
        )
        let nav = UINavigationController(rootViewController: detailVC)
        UIApplication.getTopViewController()?.present(nav, animated: true)
    }

    @objc private func closeTapped() {
        UIApplication.getTopViewController()?.dismiss(animated: true)
    }
}

extension PushNotificationRouter: UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping @Sendable (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping @Sendable () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        let id = userInfo["pokemon_id"] as? Int
        Task { @MainActor [weak self] in
            if let id { self?.presentPokemonDetail(id: id) }
            completionHandler()
        }
    }
}
