import ProjectDescription
import ProjectDescriptionHelpers

private func infoPlist(
    displayName: String,
    pokeAPIBaseURL: String,
    freeAPIBaseURL: String
) -> [String: Plist.Value] {
    [
        "CFBundleDisplayName": .string(displayName),
        "PokeAPIBaseURL": .string(pokeAPIBaseURL),
        "FreeAPIBaseURL": .string(freeAPIBaseURL),
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
    .project(target: "SharedUI", path: "../SharedUI"),
    .project(target: "Pokemon", path: "../Features/Pokemon"),
    .project(target: "Account", path: "../Features/Account"),
    .project(target: "Cart", path: "../Features/Cart"),
    .external(name: "Kingfisher"),
]

private let devAppDependencies: [TargetDependency] = baseAppDependencies + [
    .external(name: "Pulse"),
    .external(name: "PulseUI"),
]


let project = Project(
    name: "App",
    options: .options(automaticSchemesOptions: .disabled),
    settings: Settings.modular,
    targets: [
        .target(
            name: "AppTests",
            destinations: .iOS,
            product: .unitTests,
            bundleId: "com.modular.app.tests",
            deploymentTargets: .iOS("17.0"),
            buildableFolders: ["Tests"],
            dependencies: [
                .target(name: "App"),
                .project(target: "Core", path: "../Core"),
            ],
            settings: Settings.modularTests
        ),
        // Same Tests/ folder as AppTests — compiled against AppDev.
        // DEV flag mirrors the host target so #if DEV import guards resolve correctly.
        .target(
            name: "AppDevTests",
            destinations: .iOS,
            product: .unitTests,
            bundleId: "com.modular.app.devtests",
            deploymentTargets: .iOS("17.0"),
            buildableFolders: ["Tests"],
            dependencies: [
                .target(name: "AppDev"),
                .project(target: "Core", path: "../Core"),
            ],
            settings: Settings.modularTests(addingConditions: "DEV")
        ),
        .target(
            name: "App",
            destinations: .iOS,
            product: .app,
            bundleId: "com.modular.app",
            deploymentTargets: .iOS("17.0"),
            infoPlist: .extendingDefault(with: infoPlist(
                displayName: "App",
                pokeAPIBaseURL: "https://pokeapi.co/api/v2",
                freeAPIBaseURL: "https://api.freeapi.app/api/v1"
            )),
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
            infoPlist: .extendingDefault(with: infoPlist(
                displayName: "App dev",
                pokeAPIBaseURL: "https://pokeapi.co/api/v2",
                freeAPIBaseURL: "https://api.freeapi.app/api/v1"
            )),
            resources: ["Resources/**"],
            buildableFolders: ["Sources"],
            scripts: [.swiftLint],
            dependencies: devAppDependencies,
            settings: Settings.modular(addingConditions: "DEV")
        ),
    ],
    schemes: [
        .scheme(
            name: "App",
            buildAction: .buildAction(targets: [.target("App")]),
            testAction: .targets([.testableTarget(target: .target("AppTests"))])
        ),
        .scheme(
            name: "AppDev",
            buildAction: .buildAction(targets: [.target("AppDev")]),
            testAction: .targets([.testableTarget(target: .target("AppDevTests"))])
        ),
    ]
)
