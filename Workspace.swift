import ProjectDescription

let workspace = Workspace(
    name: "ModularProject",
    projects: [
        "App",
        "Core",
        "Networking",
        "Data",
        "SharedUI",
        "Features/**",
    ]
)
