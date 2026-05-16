// swift-tools-version: 5.9
import PackageDescription

#if TUIST
    import struct ProjectDescription.PackageSettings

    let packageSettings = PackageSettings(
        productTypes: [
            "Alamofire": .staticFramework,
        ]
    )
#endif

let package = Package(
    name: "ModularProject",
    dependencies: [
        .package(url: "https://github.com/realm/SwiftLint", from: "0.57.0"),
        .package(url: "https://github.com/Alamofire/Alamofire.git", from: "5.10.0"),
    ]
)
