// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Waymark",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "Waymark",
            targets: ["Waymark"]
        )
    ],
    targets: [
        .executableTarget(
            name: "Waymark",
            path: "Sources"
        )
    ]
)
