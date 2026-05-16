import ProjectDescription

extension Settings {
    public static let modular: Settings = .settings(
        base: [
            "SWIFT_VERSION": "6.0",
            "SWIFT_STRICT_CONCURRENCY": "complete",
            "SWIFT_APPROACHABLE_CONCURRENCY": "YES",
            "ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME": "",
            "DEVELOPMENT_REGION": "en",
        ]
    )
}

public extension TargetScript {
    static let swiftLint: TargetScript = .pre(
        script: """
        SWIFTLINT="${SRCROOT}/../Tuist/.build/artifacts/swiftlint/SwiftLintBinary/SwiftLintBinary.artifactbundle/macos/swiftlint"
        CONFIG="${SRCROOT}/../.swiftlint.yml"
        if [ -f "$SWIFTLINT" ]; then
            "$SWIFTLINT" lint --quiet --config "$CONFIG" "${SRCROOT}/Sources"
        else
            echo "warning: SwiftLint binary not found at $SWIFTLINT. Run 'tuist install'."
        fi
        """,
        name: "SwiftLint",
        basedOnDependencyAnalysis: false
    )
}

public extension Project {
    static func framework(
        name: String,
        dependencies: [TargetDependency] = [],
        resources: ResourceFileElements? = nil
    ) -> Project {
        Project(
            name: name,
            settings: Settings.modular,
            targets: [
                .target(
                    name: name,
                    destinations: .iOS,
                    product: .framework,
                    bundleId: "com.modular.app.\(name.lowercased())",
                    deploymentTargets: .iOS("16.0"),
                    sources: ["Sources/**"],
                    resources: resources,
                    scripts: [.swiftLint],
                    dependencies: dependencies,
                    settings: Settings.modular
                )
            ]
        )
    }
}
