import ProjectDescription
import ProjectDescriptionHelpers

let project = Project.framework(
    name: "Networking",
    dependencies: [
        .project(target: "Core", path: "../Core"),
        .external(name: "Alamofire"),
    ],
    testDependencies: []
)
