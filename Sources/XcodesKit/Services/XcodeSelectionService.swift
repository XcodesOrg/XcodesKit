import Foundation
@preconcurrency import Path
@preconcurrency import Version

/// Errors produced while resolving an installed Xcode selection.
public enum XcodeSelectionError: LocalizedError, Equatable, Sendable {
    case invalidIndex(min: Int, max: Int, given: String?)

    public var errorDescription: String? {
        switch self {
        case let .invalidIndex(min, max, given):
            return "Not a valid number. Expecting a whole number between \(min)-\(max), but given \(given ?? "nothing")."
        }
    }
}

/// A resolved selection action for an installed Xcode path or version.
public enum XcodeSelectionRequest: Equatable, Sendable {
    /// The requested version is already selected.
    case alreadySelectedVersion(Version)
    /// The requested path is already selected.
    case alreadySelectedPath(String)
    /// Select a known installed Xcode.
    case selectInstalledXcode(InstalledXcode)
    /// Select a path that may not be represented by the installed Xcode list.
    case selectPath(String)
}

/// Resolves user input into Xcode selection actions.
public struct XcodeSelectionService: Sendable {
    private let versionFile: XcodeVersionFileService

    /// Creates a service that can optionally read `.xcode-version` files.
    public init(versionFile: XcodeVersionFileService = XcodeVersionFileService()) {
        self.versionFile = versionFile
    }

    /// Resolves a path, version string, or `.xcode-version` file into a selection request.
    public func request(
        pathOrVersion: String,
        installedXcodes: [InstalledXcode],
        selectedXcodePath: String,
        versionFileDirectory: Path = Path(.cwd)
    ) -> XcodeSelectionRequest {
        let versionToSelect = pathOrVersion.isEmpty
            ? versionFile.version(inDirectory: versionFileDirectory)
            : Version(xcodeVersion: pathOrVersion)

        if let version = versionToSelect,
           let installedXcode = installedXcodes.first(withVersion: version) {
            let selectedInstalledXcode = XcodeListPresentationService.selectedInstalledXcode(
                in: installedXcodes,
                selectedXcodePath: selectedXcodePath
            )

            if installedXcode.version == selectedInstalledXcode?.version {
                return .alreadySelectedVersion(version)
            }

            return .selectInstalledXcode(installedXcode)
        }

        let pathToSelect = pathOrVersion.trimmingCharacters(in: .whitespacesAndNewlines)
        let currentPath = selectedXcodePath.trimmingCharacters(in: .whitespacesAndNewlines)

        if pathToSelect == currentPath {
            return .alreadySelectedPath(pathOrVersion)
        }

        return .selectPath(pathToSelect)
    }

    /// Returns the installed Xcode selected by a one-based display index.
    public func installedXcode(
        fromSelection selection: String?,
        installedXcodes: [InstalledXcode]
    ) throws -> InstalledXcode {
        let sortedInstalledXcodes = installedXcodes.sorted { $0.version < $1.version }

        guard
            let selection,
            let selectionNumber = Int(selection),
            sortedInstalledXcodes.indices.contains(selectionNumber - 1)
        else {
            throw XcodeSelectionError.invalidIndex(min: 1, max: sortedInstalledXcodes.count, given: selection)
        }

        return sortedInstalledXcodes[selectionNumber - 1]
    }
}
