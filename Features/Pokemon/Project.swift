import ProjectDescription
import ProjectDescriptionHelpers

let project = Project.framework(
    name: "Pokemon",
    dependencies: [
        .project(target: "Core", path: "../../Core"),
        .project(target: "SharedUI", path: "../../SharedUI"),
    ]
)
