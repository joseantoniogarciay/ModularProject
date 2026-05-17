// swift-tools-version: 5.9
import PackageDescription

#if TUIST
    import struct ProjectDescription.PackageSettings

    let packageSettings = PackageSettings(
        productTypes: [
            "Alamofire": .staticFramework,
            "Kingfisher": .staticFramework,
            "Pulse": .staticFramework,
            "PulseUI": .staticFramework,
        ],
        baseSettings: .settings(base: [
            "IPHONEOS_DEPLOYMENT_TARGET": "17.0",
        ]),
        targetSettings: [
            "Alamofire": ["IPHONEOS_DEPLOYMENT_TARGET": "17.0"],
            "Kingfisher": ["IPHONEOS_DEPLOYMENT_TARGET": "17.0"],
            "Pulse": ["IPHONEOS_DEPLOYMENT_TARGET": "17.0"],
            "PulseUI": ["IPHONEOS_DEPLOYMENT_TARGET": "17.0"],
            "PulseCore": ["IPHONEOS_DEPLOYMENT_TARGET": "17.0"],
        ]
    )
#endif

let package = Package(
    name: "ModularProject",
    dependencies: [
        .package(url: "https://github.com/realm/SwiftLint", exact: "0.63.2"),
        .package(url: "https://github.com/Alamofire/Alamofire.git", exact: "5.12.0"),
        .package(url: "https://github.com/onevcat/Kingfisher.git", exact: "8.9.0"),
        .package(url: "https://github.com/kean/Pulse.git", exact: "5.2.2"),
    ]
)
