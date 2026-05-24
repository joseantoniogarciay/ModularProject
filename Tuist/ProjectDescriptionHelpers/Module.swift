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
        modular(overriding: ["SWIFT_ACTIVE_COMPILATION_CONDITIONS": "$(inherited) \(conditions)"])
    }

    /// Like `modular` but merges arbitrary extra keys on top of the shared base.
    /// Later entries in `overrides` win over the base.
    public static func modular(overriding overrides: SettingsDictionary) -> Settings {
        var base = modularBaseSettings
        for (key, value) in overrides { base[key] = value }
        return .settings(base: base)
    }

    /// Settings for unit-test targets: same base as `modular` plus:
    /// - Code-signing disabled (simulator builds don't need a profile).
    /// - Warnings treated as errors, because the compiler suppresses test-target
    ///   warnings by default and they would otherwise go unnoticed.
    public static let modularTests: Settings = modularTests()

    /// Settings for UI test targets: same base as `modularTests` plus
    /// `TEST_TARGET_NAME` pointing to the app being exercised.
    ///
    /// Code signing is intentionally NOT disabled here (unlike `modularTests`).
    /// UI test runners are separate processes that Xcode must launch and attach its
    /// debugger to — this requires at least ad-hoc signing. Xcode defaults to `-`
    /// (ad-hoc) for simulator builds, which is enough. When running from CI via
    /// `xcodebuild test`, pass `CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO`
    /// on the command line to suppress signing there.
    ///
    /// - Parameters:
    ///   - targetName: The Xcode target name of the host app (e.g. `"App"` or `"AppDev"`).
    ///   - conditions: Optional extra compilation conditions to mirror the host variant's flags
    ///     (e.g. `"DEV"` for `AppDevUITests` so `#if DEV` guards resolve correctly).
    public static func modularUITests(targetName: String, addingConditions conditions: String = "") -> Settings {
        var base = modularBaseSettings
        base["SWIFT_TREAT_WARNINGS_AS_ERRORS"] = "YES"
        base["TEST_TARGET_NAME"] = .string(targetName)
        if !conditions.isEmpty {
            base["SWIFT_ACTIVE_COMPILATION_CONDITIONS"] = "$(inherited) \(conditions)"
        }
        return .settings(base: base)
    }

    /// Like `modularTests` but also activates extra compilation conditions.
    /// Use when the test target must mirror a production variant's flags —
    /// e.g. `AppDevTests` passes `"DEV"` so `#if DEV` import guards resolve correctly.
    public static func modularTests(addingConditions conditions: String = "") -> Settings {
        var base = modularBaseSettings
        base["CODE_SIGN_IDENTITY"] = ""
        base["CODE_SIGNING_REQUIRED"] = "NO"
        base["CODE_SIGNING_ALLOWED"] = "NO"
        base["SWIFT_TREAT_WARNINGS_AS_ERRORS"] = "YES"
        if !conditions.isEmpty {
            base["SWIFT_ACTIVE_COMPILATION_CONDITIONS"] = "$(inherited) \(conditions)"
        }
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
    /// Creates a static framework project.
    ///
    /// - Parameters:
    ///   - testDependencies: When non-nil, a `<Name>Tests` unit-test target is added whose
    ///     sources live in `Tests/`. Pass `[]` when no extra dependencies are needed beyond
    ///     the framework under test itself.
    ///
    /// Scheme strategy: one explicit scheme named `<Name>` is always generated.
    /// When a test target exists it is wired into that scheme's test action, so
    /// Tuist does not auto-generate a separate `<Name>Tests` scheme or the
    /// duplicate `<Name>_<Name>` scheme that appears when no explicit schemes are
    /// defined.
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

        let testAction: TestAction? = testDependencies.map { _ in
            .targets([.testableTarget(target: .target("\(name)Tests"))])
        }

        let scheme = Scheme.scheme(
            name: name,
            buildAction: .buildAction(targets: [.target(name)]),
            testAction: testAction
        )

        return Project(
            name: name,
            options: .options(automaticSchemesOptions: .disabled),
            settings: Settings.modular,
            targets: targets,
            schemes: [scheme]
        )
    }
}
