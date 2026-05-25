# ``XcodesKit``

Build Xcode and simulator-runtime management features into Swift apps and tools.

## Overview

XcodesKit is the shared package behind XcodesOrg apps. It exposes models and services for discovering available Xcode releases, reading local installations, choosing an installed Xcode, downloading and installing archives, uninstalling Xcode bundles, and managing simulator runtimes.

Most API is organized around small `Sendable` service types. Default initializers use the real network, filesystem, and shell implementations. Initializers that accept closures are intended for tests, previews, and host applications that need to control side effects.

```swift
import XcodesKit

let listService = XcodeListService()
let releases = try await listService.availableXcodes(from: .default)
```

### Common Workflows

Use ``XcodeListService`` to load release metadata from Apple or Xcode Releases.

```swift
let service = XcodeListService()
let xcodes = try await service.availableXcodes(from: .xcodeReleases)

let latest = xcodes.first
```

Use ``InstalledXcodeDiscoveryService`` to read Xcode bundles from a directory.

```swift
let discovery = InstalledXcodeDiscoveryService()
let installed = discovery.installedXcodes(in: "/Applications")
```

Use ``XcodeListComposer`` to combine available releases, installed bundles, and selection state into UI-ready list items.

```swift
let items = XcodeListComposer().compose(
    availableXcodes: available,
    installedXcodes: installed,
    selectedXcodePath: selectedPath,
    existingXcodes: previousItems,
    dataSource: .xcodeReleases
)
```

Use ``XcodeSelectionService`` to resolve a user-entered path, version string, or `.xcode-version` file into a selection request.

```swift
let request = XcodeSelectionService().request(
    pathOrVersion: "15.4",
    installedXcodes: installed,
    selectedXcodePath: selectedPath
)
```

Use ``RuntimeService`` and the runtime installation services to list, download, and install simulator runtimes.

```swift
let runtimeService = RuntimeService()
let response = try await runtimeService.downloadableRuntimes()
let installed = try await runtimeService.installedRuntimes()
```

### Working With Side Effects

Many services accept closure dependencies so public API consumers can inject their own network, filesystem, or shell behavior.

```swift
let service = XcodeListService { request in
    let data = try fixtureData(for: request)
    return (data, URLResponse())
}
```

For package-wide test hooks, use ``configureXcodesKitFileContents(_:)`` and ``configureXcodesKitArchs(_:)`` to replace file and architecture lookup behavior.

## Topics

### Release Discovery

- ``XcodeListService``
- ``DataSource``
- ``XcodeListDataSource``
- ``XcodeListStore``
- ``AvailableXcodeCache``
- ``XcodeListComposer``
- ``XcodeListPresentationService``
- ``XcodeListItem``
- ``XcodeListFilters``
- ``XcodeListVersionFilter``
- ``XcodeMajorVersionGroup``
- ``XcodeMinorVersionGroup``
- ``XcodeListElementMajorVersionGroup``
- ``XcodeListElementMinorVersionGroup``

### Xcode Models

- ``AvailableXcodeRelease``
- ``AvailableXcode``
- ``InstalledXcode``
- ``XcodeID``
- ``XcodeInstallState``
- ``XcodeInstallationStep``
- ``XcodeBundleInfo``
- ``InfoPlist``
- ``VersionPlist``
- ``AutoInstallationType``
- ``SelectedActionType``

### Xcode Release Metadata

- ``XcodeRelease``
- ``XcodeVersion``
- ``V``
- ``Release``
- ``Architecture``
- ``ArchitectureVariant``
- ``ArchitectureFilter``
- ``SDKs``
- ``Compilers``
- ``Checksums``
- ``Link``
- ``Links``
- ``YMD``
- ``Downloads``
- ``Download``
- ``ByteCount``

### Installation And Archives

- ``XcodeArchiveService``
- ``XcodeArchive``
- ``XcodeArchiveDownloader``
- ``XcodeInstallResolutionService``
- ``XcodeInstallRequest``
- ``XcodeInstallResolution``
- ``XcodeInstallResolutionError``
- ``XcodeArchiveInstallService``
- ``XcodeArchiveInstallStep``
- ``XcodeArchiveInstallError``
- ``XcodeUnarchiveService``
- ``XcodeUnarchiveStep``
- ``XcodeUnarchiveError``
- ``XcodeInstallRetryService``
- ``XcodeUpdatePolicy``
- ``XcodeAutoInstallService``
- ``XcodeAutoInstallDecision``
- ``XcodeCompatibilityService``
- ``XcodeCompatibilityStatus``
- ``XcodeValidationService``
- ``XcodeValidationError``
- ``XcodeSignatureVerifier``
- ``XcodeSignature``

### Post-Install And Selection

- ``InstalledXcodeDiscoveryService``
- ``XcodePostInstallWorkflowService``
- ``XcodePostInstallPreparationService``
- ``XcodePostInstallService``
- ``XcodeSelectionService``
- ``XcodeSelectionRequest``
- ``XcodeSelectionError``
- ``XcodeSelectionFilesystemService``
- ``XcodeSelectionFilesystemError``
- ``XcodeUninstallService``
- ``XcodesPathResolver``
- ``XcodeVersionFileService``

### Runtime Discovery And Installation

- ``RuntimeService``
- ``DownloadableRuntimesResponse``
- ``DownloadableRuntime``
- ``InstalledRuntime``
- ``RuntimeInstallState``
- ``RuntimeInstallationStep``
- ``RuntimeListStore``
- ``RuntimeListPresentationService``
- ``RuntimeInstallationLookupService``
- ``RuntimeInstallPolicy``
- ``RuntimeInstallMethod``
- ``RuntimeInstallPolicyError``
- ``RuntimeArchiveService``
- ``RuntimeArchiveDownloadStrategyService``
- ``RuntimeArchiveInstallService``
- ``RuntimeArchiveInstallError``
- ``RuntimePackageInstallService``
- ``RuntimeXcodebuildInstallService``
- ``XcodebuildRuntimeDownloadService``
- ``DownloadableRuntimeCache``
- ``CoreSimulatorPlist``
- ``CoreSimulatorImage``
- ``CoreSimulatorRuntimeInfo``
- ``SDKToSeedMapping``
- ``SDKToSimulatorMapping``
- ``makeRuntimeVersion(for:betaNumber:)``

### Downloads, Files, And Shell

- ``ArchiveDownloadService``
- ``ArchiveDownloadStrategyService``
- ``Aria2DownloadService``
- ``Aria2CError``
- ``ArchiveCancellationCleanupService``
- ``CodableFileStore``
- ``ApplicationSupportMigrationService``
- ``HostHardware``
- ``XcodesShell``
- ``XcodesProcess``
- ``ProcessOutput``
- ``ProcessExecutionError``

### Progress And Concurrency

- ``ProgressObservation``
- ``ProgressObservedProperty``
- ``OneShotContinuation``
- ``attemptRetryableTask(_:maxAttempts:shouldRetry:onRetry:)``
- ``attemptResumableTask(_:maxAttempts:onRetry:)``

### Environment And Errors

- ``XcodesKitEnvironment``
- ``XcodesKitFiles``
- ``configureXcodesKitFileContents(_:)``
- ``configureXcodesKitArchs(_:)``
- ``XcodesKitError``
