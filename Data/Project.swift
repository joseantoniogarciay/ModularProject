import ProjectDescription
import ProjectDescriptionHelpers

let project = Project.framework(
    name: "Data",
    dependencies: [
        .project(target: "Core", path: "../Core"),
        .project(target: "Networking", path: "../Networking"),
    ]
)
