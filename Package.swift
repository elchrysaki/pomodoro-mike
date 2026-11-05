// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Mike",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Mike", targets: ["Mike"])
    ],
    targets: [
        .executableTarget(
            name: "Mike",
            path: "Sources/Mike"
        )
    ]
)
