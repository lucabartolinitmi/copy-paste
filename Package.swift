// swift-tools-version:5.7
import PackageDescription

let package = Package(
    name: "CopyPaste",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "CopyPaste",
            path: "Sources/CopyPaste",
            exclude: ["Info.plist"],
            linkerSettings: [
                .linkedFramework("Carbon"),
                .linkedFramework("ApplicationServices"),
            ]
        )
    ]
)
