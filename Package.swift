// swift-tools-version: 5.9
import PackageDescription

// The menu-bar app and the private CoreGraphics wrapper are macOS-only.
// PhoneScreenCore stays portable so `swift test` can run the resolution,
// parser, and profile tests on any host.

var products: [Product] = [
    .library(name: "PhoneScreenCore", targets: ["PhoneScreenCore"]),
]

var targets: [Target] = [
    .target(name: "PhoneScreenCore"),
    .testTarget(
        name: "PhoneScreenCoreTests",
        dependencies: ["PhoneScreenCore"]
    ),
]

#if os(macOS)
products.append(.executable(name: "PhoneScreen", targets: ["PhoneScreen"]))
targets.append(contentsOf: [
    .target(
        name: "VirtualDisplaySPI",
        path: "Sources/VirtualDisplaySPI",
        publicHeadersPath: "include",
        cSettings: [
            .headerSearchPath("include"),
        ],
        linkerSettings: [
            .linkedFramework("CoreGraphics"),
            .linkedFramework("Foundation"),
        ]
    ),
    .executableTarget(
        name: "PhoneScreen",
        dependencies: ["PhoneScreenCore", "VirtualDisplaySPI"],
        linkerSettings: [
            .linkedFramework("AppKit"),
            .linkedFramework("CoreGraphics"),
            .linkedFramework("Carbon"),
            .linkedFramework("ServiceManagement"),
        ]
    ),
])
#endif

#if os(macOS)
let package = Package(
    name: "PhoneScreen",
    platforms: [.macOS(.v14)],
    products: products,
    targets: targets
)
#else
let package = Package(
    name: "PhoneScreen",
    products: products,
    targets: targets
)
#endif
