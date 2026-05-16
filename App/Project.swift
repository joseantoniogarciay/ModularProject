import ProjectDescription
import ProjectDescriptionHelpers

let project = Project(
    name: "App",
    settings: Settings.modular,
    targets: [
        .target(
            name: "App",
            destinations: .iOS,
            product: .app,
            bundleId: "com.modular.app",
            deploymentTargets: .iOS("16.0"),
            infoPlist: .extendingDefault(with: [
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
            ]),
            resources: ["Resources/**"],
            buildableFolders: ["Sources"],
            scripts: [.swiftLint],
            dependencies: [
                .project(target: "Core", path: "../Core"),
                .project(target: "Networking", path: "../Networking"),
                .project(target: "Data", path: "../Data"),
                .project(target: "Pokemon", path: "../Features/Pokemon"),
            ],
            settings: Settings.modular
        ),
    ]
)
