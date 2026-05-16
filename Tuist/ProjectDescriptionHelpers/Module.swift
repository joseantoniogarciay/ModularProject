import ProjectDescription

private let modularBaseSettings: SettingsDictionary = [
    "SWIFT_VERSION": "6.0",
    "SWIFT_STRICT_CONCURRENCY": "complete",
    "SWIFT_APPROACHABLE_CONCURRENCY": "YES",
    "ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME": "",
    "DEVELOPMENT_REGION": "en",
]

extension Settings {
    public static let modular: Settings = .settings(base: modularBaseSettings)

    public static func modular(addingConditions conditions: String) -> Settings {
        var base = modularBaseSettings
        base["SWIFT_ACTIVE_COMPILATION_CONDITIONS"] = "$(inherited) \(conditions)"
        return .settings(base: base)
    }
}

public extension TargetScript {
    static let swiftLint: TargetScript = .pre(
        script: """
        PROJECT_ROOT="${SRCROOT}"
        while [ ! -d "${PROJECT_ROOT}/Tuist" ] && [ "${PROJECT_ROOT}" != "/" ]; do
            PROJECT_ROOT="$(dirname "${PROJECT_ROOT}")"
        done
        SWIFTLINT="${PROJECT_ROOT}/Tuist/.build/artifacts/swiftlint/SwiftLintBinary/SwiftLintBinary.artifactbundle/macos/swiftlint"
        CONFIG="${PROJECT_ROOT}/.swiftlint.yml"
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
                    product: .staticFramework,
                    bundleId: "com.modular.app.\(name.lowercased())",
                    deploymentTargets: .iOS("17.0"),
                    resources: resources,
                    buildableFolders: ["Sources"],
                    scripts: [.swiftLint],
                    dependencies: dependencies,
                    settings: Settings.modular
                )
            ]
        )
    }
}
