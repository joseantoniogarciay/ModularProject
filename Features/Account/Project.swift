import ProjectDescription
import ProjectDescriptionHelpers

let project = Project.framework(
    name: "Account",
    dependencies: [
        .project(target: "Core", path: "../../Core"),
        .project(target: "SharedUI", path: "../../SharedUI"),
    ]
)
