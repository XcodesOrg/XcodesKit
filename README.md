# XcodesKit

XcodesKit is the shared Swift package that powers XcodesOrg apps. It contains the core models, services, environment hooks, and filesystem/download workflows used by XcodesApp to discover, download, install, update, and manage Xcode releases and simulator runtimes.

## Requirements

- macOS 13 or newer
- Swift 6.0 or newer

## Package

Add XcodesKit as a Swift Package dependency:

```swift
.package(url: "https://github.com/XcodesOrg/XcodesKit", branch: "main")
```

Then depend on the library product from your target:

```swift
.product(name: "XcodesKit", package: "XcodesKit")
```

## API Documentation

XcodesKit includes a DocC catalog at `Sources/XcodesKit/Documentation.docc`.
Open the package in Xcode and choose **Product > Build Documentation** to browse the public API grouped by workflow.

The main entry points are:

- `XcodeListService` for loading Xcode release metadata from Apple or Xcode Releases.
- `InstalledXcodeDiscoveryService` for reading installed Xcode bundles.
- `XcodeListComposer` and `XcodeListPresentationService` for building UI-ready Xcode lists.
- `XcodeArchiveService`, `XcodeArchiveInstallService`, and `XcodeUnarchiveService` for archive download and install workflows.
- `XcodeSelectionService` for selecting an installed Xcode.
- `RuntimeService` and the runtime install services for simulator runtime discovery and installation.

Most services provide default initializers for real network, filesystem, and shell behavior, plus closure-based initializers for tests and host-app integration.

## Development

Build the package:

```sh
swift build
```

Run the test suite:

```sh
swift test
```
