// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "DuoSound",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "DuoSound",
            path: "DuoSound",
            exclude: ["Info.plist"],
            resources: [
                .process("Assets.xcassets"),
            ],
            swiftSettings: [
                .unsafeFlags(["-strict-concurrency=targeted"]),
            ],
            linkerSettings: [
                .linkedFramework("CoreAudio"),
                .linkedFramework("AudioToolbox"),
                .linkedFramework("AppKit"),
            ]
        )
    ]
)
