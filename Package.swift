// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "CourseIslandApp",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .executable(
            name: "CourseIslandApp",
            targets: ["CourseIslandApp"]
        ),
    ],
    targets: [
        .executableTarget(
            name: "CourseIslandApp"
        ),
        .testTarget(
            name: "CourseIslandAppTests",
            dependencies: ["CourseIslandApp"],
            path: "Tests/CourseIslandAppTests",
            resources: [
                .process("Fixtures"),
            ]
        ),
    ]
)
