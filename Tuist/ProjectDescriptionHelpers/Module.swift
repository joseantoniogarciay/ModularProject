import ProjectDescription

private let modularBaseSettings: SettingsDictionary = [
    "SWIFT_VERSION": "6.0",
    "SWIFT_STRICT_CONCURRENCY": "complete",
    "SWIFT_APPROACHABLE_CONCURRENCY": "YES",
    "ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME": "",
    "DEVELOPMENT_REGION": "en",
    "ENABLE_MODULE_VERIFIER": "NO",
    "ENABLE_USER_SCRIPT_SANDBOXING": "NO",
    "STRING_CATALOG_GENERATE_SYMBOLS": "NO",
]

extension Settings {
    public static let modular: Settings = .settings(base: modularBaseSettings)

    public static func modular(addingConditions conditions: String) -> Settings {
        var base = modularBaseSettings
        base["SWIFT_ACTIVE_COMPILATION_CONDITIONS"] = "$(inherited) \(conditions)"
        return .settings(base: base)
    }

    /// Settings for unit-test targets: same base as `modular` plus:
    /// - Code-signing disabled (simulator builds don't need a profile).
    /// - Warnings treated as errors, because the compiler suppresses test-target
    ///   warnings by default and they would otherwise go unnoticed.
    public static let modularTests: Settings = {
        var base = modularBaseSettings
        base["CODE_SIGN_IDENTITY"] = ""
        base["CODE_SIGNING_REQUIRED"] = "NO"
        base["CODE_SIGNING_ALLOWED"] = "NO"
        base["SWIFT_TREAT_WARNINGS_AS_ERRORS"] = "YES"
        return .settings(base: base)
    }()
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
    /// Creates a static framework project.
    ///
    /// - Parameters:
    ///   - testDependencies: When non-nil, a `<Name>Tests` unit-test target is added whose
    ///     sources live in `Tests/`. Pass `[]` when no extra dependencies are needed beyond
    ///     the framework under test itself.
    static func framework(
        name: String,
        dependencies: [TargetDependency] = [],
        resources: ResourceFileElements? = nil,
        testDependencies: [TargetDependency]? = nil
    ) -> Project {
        var targets: [Target] = [
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

        if let testDependencies {
            targets.append(
                .target(
                    name: "\(name)Tests",
                    destinations: .iOS,
                    product: .unitTests,
                    bundleId: "com.modular.app.\(name.lowercased())tests",
                    deploymentTargets: .iOS("17.0"),
                    buildableFolders: ["Tests"],
                    dependencies: [.target(name: name)] + testDependencies,
                    settings: Settings.modularTests
                )
            )
        }

        return Project(
            name: name,
            settings: Settings.modular,
            targets: targets
        )
    }
}
