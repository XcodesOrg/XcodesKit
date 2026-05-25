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

## Development

Build the package:

```sh
swift build
```

Run the test suite:

```sh
swift test
```
