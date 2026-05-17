import ProjectDescription
import ProjectDescriptionHelpers

private func infoPlist(displayName: String) -> [String: Plist.Value] {
    [
        "CFBundleDisplayName": .string(displayName),
        "UILaunchScreen": [
            "UIColorName": "Background",
            "UIImageName": "Logo",
        ],
        "UIApplicationSceneManifest": [
            "UIApplicationSupportsMultipleScenes": false,
            "UISceneConfigurations": [
                "UIWindowSceneSessionRoleApplication": [
                    [
                        "UISceneConfigurationName": "Default Configuration",
                        "UISceneDelegateClassName": "$(PRODUCT_MODULE_NAME).SceneDelegate",
                    ],
                ],
            ],
        ],
    ]
}

private let baseAppDependencies: [TargetDependency] = [
    .project(target: "Core", path: "../Core"),
    .project(target: "Networking", path: "../Networking"),
    .project(target: "Data", path: "../Data"),
    .project(target: "Pokemon", path: "../Features/Pokemon"),
    .project(target: "Account", path: "../Features/Account"),
]

private let devAppDependencies: [TargetDependency] = baseAppDependencies + [
    .external(name: "Pulse"),
    .external(name: "PulseUI"),
]

let project = Project(
    name: "App",
    settings: Settings.modular,
    targets: [
        .target(
            name: "App",
            destinations: .iOS,
            product: .app,
            bundleId: "com.modular.app",
            deploymentTargets: .iOS("17.0"),
            infoPlist: .extendingDefault(with: infoPlist(displayName: "App")),
            resources: ["Resources/**"],
            buildableFolders: ["Sources"],
            scripts: [.swiftLint],
            dependencies: baseAppDependencies,
            settings: Settings.modular
        ),
        .target(
            name: "AppDev",
            destinations: .iOS,
            product: .app,
            bundleId: "com.modular.app.dev",
            deploymentTargets: .iOS("17.0"),
            infoPlist: .extendingDefault(with: infoPlist(displayName: "App dev")),
            resources: ["Resources/**"],
            buildableFolders: ["Sources"],
            scripts: [.swiftLint],
            dependencies: devAppDependencies,
            settings: Settings.modular(addingConditions: "DEV")
        ),
    ]
)
