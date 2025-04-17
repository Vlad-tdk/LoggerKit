// swift-tools-version:5.9
import PackageDescription

let package = Package(
  name: "LoggerKit",
  platforms: [
    .iOS(.v17),
    .macOS(.v14),
  ],
  products: [
    .library(name: "LoggerKit", targets: ["LoggerKit"])
  ],
  dependencies: [
    .package(url: "https://github.com/weichsel/ZIPFoundation.git", from: "0.9.0")
  ],
  targets: [
    .target(
      name: "LoggerKit",
      dependencies: ["ZIPFoundation"],
      path: "LoggerKit",
      sources: [
        "Level.swift",
        "Log.swift",
        "Logger.swift",
        "LogStyle.swift",
        "LogDestination.swift",
        "Logger+Adapters.swift",
        "LogAdapterProtocol.swift",
        "OSLogAdapter.swift",
        "LogosAdapter.swift",
        "LogUploaderService.swift",
        "LogExporterService.swift",
        "LogViewerView.swift",
        "LogViewerView+Extension.swift",
        "LogViewerView+Action.swift"
      ]
    )
  ]
)
