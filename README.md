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

The CLI and app also have opt-in download smoke tests. With local copies of
Xcode 27.3 beta in both formats, run:

```sh
python3 Tests/serve_archive_smoke_fixtures.py /path/to/Xcode_27.3_beta.aea /path/to/Xcode_27.3_beta.xip
```

Use the printed URL as `XCODES_ARCHIVE_SMOKE_URL`. Run the CLI's
`test_InstallDownloaded…` tests with `HOME` and `XCODES_ARCHIVE_SMOKE_HOME`
set to the same fresh `mktemp -d /tmp/xcodes-cli-smoke.XXXXXXXX` directory,
and set `XCODES_ARCHIVE_SMOKE_ARIA2` to the `aria2c` executable. Run the app's
`test_Install_Downloaded…` tests with `TEST_RUNNER_XCODES_ARCHIVE_SMOKE_URL`
when using `xcodebuild`. For a known damaged XIP fixture, set
`XCODES_ARCHIVE_SMOKE_EXPECT_DAMAGED_XIP=1` (prefix it with `TEST_RUNNER_`
for the app under `xcodebuild`) to test rejection instead of installation.
