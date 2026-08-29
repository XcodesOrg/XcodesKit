import Foundation

/// Combines available releases, installed bundles, and selection state into list items.
public struct XcodeListComposer: Sendable {
    public init() {}

    /// Builds the canonical Xcode list shown by apps and tools.
    ///
    /// Existing installing states are preserved when the same Xcode is still present in the refreshed
    /// list. Installed Xcodes that are missing from the available list are appended so users can still
    /// see and manage local-only installations.
    public func compose(
        availableXcodes: [AvailableXcode],
        installedXcodes: [InstalledXcode],
        selectedXcodePath: String?,
        existingXcodes: [XcodeListItem],
        dataSource: XcodeListDataSource
    ) -> [XcodeListItem] {
        var adjustedAvailableXcodes = availableXcodes

        if dataSource == .apple {
            adjustedAvailableXcodes = Self.adjustingAvailableXcodesForInstalledBuildMetadata(
                availableXcodes,
                installedXcodes: installedXcodes
            )
        }

        var newAllXcodes = XcodeListService.filteringPrereleasesWithDuplicateBuildMetadata(adjustedAvailableXcodes)
            .map { availableXcode -> XcodeListItem in
                let installedXcode = installedXcodes.first { installedXcode in
                    availableXcode.version.isEquivalent(to: installedXcode.version)
                }
                let identicalBuilds = XcodeListService.identicalBuildIDs(for: availableXcode, in: availableXcodes)
                let existingXcodeInstallState = existingXcodes
                    .first { $0.id == availableXcode.xcodeID && ($0.installState.installing || $0.installState.uninstalling) }?
                    .installState
                let defaultXcodeInstallState: XcodeInstallState = installedXcode.map { .installed($0.path) } ?? .notInstalled

                return XcodeListItem(
                    version: availableXcode.version,
                    identicalBuilds: identicalBuilds,
                    installState: existingXcodeInstallState ?? defaultXcodeInstallState,
                    selected: installedXcode != nil && selectedXcodePath?.hasPrefix(installedXcode!.path.string) == true,
                    requiredMacOSVersion: availableXcode.requiredMacOSVersion,
                    releaseNotesURL: availableXcode.releaseNotesURL,
                    releaseDate: availableXcode.releaseDate,
                    sdks: availableXcode.sdks,
                    compilers: availableXcode.compilers,
                    downloadFileSize: availableXcode.fileSize,
                    architectures: availableXcode.architectures
                )
            }

        for installedXcode in installedXcodes {
            if !newAllXcodes.contains(where: { xcode in xcode.version.isEquivalent(to: installedXcode.version) }) {
                newAllXcodes.append(
                    XcodeListItem(
                        version: installedXcode.version,
                        installState: .installed(installedXcode.path),
                        selected: selectedXcodePath?.hasPrefix(installedXcode.path.string) == true
                    )
                )
            }
        }

        return newAllXcodes.sorted { $0.version > $1.version }
    }

    /// Reuses build metadata from installed Xcodes when Apple's available list omits or mismatches it.
    public static func adjustingAvailableXcodesForInstalledBuildMetadata(
        _ availableXcodes: [AvailableXcode],
        installedXcodes: [InstalledXcode]
    ) -> [AvailableXcode] {
        var adjustedAvailableXcodes = availableXcodes

        for installedXcode in installedXcodes {
            if let index = adjustedAvailableXcodes.map(\.version).firstIndex(where: { $0.buildMetadataIdentifiers == installedXcode.version.buildMetadataIdentifiers }) {
                adjustedAvailableXcodes[index].xcodeID = installedXcode.xcodeID
            } else if let index = adjustedAvailableXcodes.firstIndex(where: { availableXcode in
                availableXcode.version.isEquivalent(to: installedXcode.version) &&
                    availableXcode.version.buildMetadataIdentifiers.isEmpty
            }) {
                adjustedAvailableXcodes[index].xcodeID = installedXcode.xcodeID
            }
        }

        return adjustedAvailableXcodes
    }
}
