import Foundation
@preconcurrency import Path
@preconcurrency import Version

/// A user-facing request to install or download Xcode.
public enum XcodeInstallRequest: Equatable, Sendable {
    /// Resolve the newest stable release.
    case latest
    /// Resolve the newest prerelease by release date.
    case latestPrerelease
    /// Use a specific available Xcode object.
    case availableXcode(AvailableXcode)
    /// Resolve a version string, or fall back to `.xcode-version` when the string is empty.
    case version(String)
    /// Install from a local archive at a known path.
    case path(versionString: String, path: Path)
}

/// The resolved source for an Xcode install or download request.
public enum XcodeInstallResolution: Equatable, Sendable {
    /// Download the requested version, optionally with a fully resolved available Xcode.
    case download(version: Version, resolvedXcode: AvailableXcode?)
    /// Install from a local archive URL.
    case localArchive(AvailableXcode, URL)
}

/// Errors produced while resolving an Xcode install request.
public enum XcodeInstallResolutionError: LocalizedError, Equatable, Sendable {
    case invalidVersion(String)
    case noReleaseVersionAvailable
    case noPrereleaseVersionAvailable
    case versionAlreadyInstalled(InstalledXcode)

    public var errorDescription: String? {
        switch self {
        case let .invalidVersion(version):
            return "\(version) is not a valid version number."
        case .noReleaseVersionAvailable:
            return "No release versions available."
        case .noPrereleaseVersionAvailable:
            return "No prerelease versions available."
        case let .versionAlreadyInstalled(installedXcode):
            return "\(installedXcode.version.appleDescription) is already installed at \(installedXcode.path)"
        }
    }
}

/// Resolves install requests against available releases and installed Xcodes.
public struct XcodeInstallResolutionService: Sendable {
    private let versionFile: XcodeVersionFileService

    /// Creates a resolver that can optionally read `.xcode-version` files.
    public init(versionFile: XcodeVersionFileService = XcodeVersionFileService()) {
        self.versionFile = versionFile
    }

    /// Resolves a request into a concrete download or local archive action.
    ///
    /// When `willInstall` is true, the resolver rejects versions that are already installed.
    public func resolve(
        _ request: XcodeInstallRequest,
        availableXcodes: [AvailableXcode],
        installedXcodes: [InstalledXcode],
        willInstall: Bool,
        versionFileDirectory: Path = Path(.cwd)
    ) throws -> XcodeInstallResolution {
        switch request {
        case .latest:
            guard let xcode = latestRelease(in: availableXcodes) else {
                throw XcodeInstallResolutionError.noReleaseVersionAvailable
            }
            try ensureNotInstalled(xcode.version, installedXcodes: installedXcodes, willInstall: willInstall)
            return .download(version: xcode.version, resolvedXcode: xcode)

        case .latestPrerelease:
            guard let xcode = latestPrerelease(in: availableXcodes) else {
                throw XcodeInstallResolutionError.noPrereleaseVersionAvailable
            }
            try ensureNotInstalled(xcode.version, installedXcodes: installedXcodes, willInstall: willInstall)
            return .download(version: xcode.version, resolvedXcode: xcode)

        case let .availableXcode(xcode):
            try ensureNotInstalled(xcode.version, installedXcodes: installedXcodes, willInstall: willInstall)
            return .download(version: xcode.version, resolvedXcode: xcode)

        case let .version(versionString):
            let version = try parsedVersion(versionString, versionFileDirectory: versionFileDirectory)
            try ensureNotInstalled(version, installedXcodes: installedXcodes, willInstall: willInstall)
            return .download(version: version, resolvedXcode: nil)

        case let .path(versionString, path):
            let version = try parsedVersion(versionString, versionFileDirectory: versionFileDirectory)
            let xcode = AvailableXcode(
                version: version,
                url: path.url,
                filename: String(path.string.suffix(fromLast: "/")),
                releaseDate: nil
            )
            return .localArchive(xcode, path.url)
        }
    }

    /// Returns the newest non-prerelease Xcode in the available list.
    public func latestRelease(in availableXcodes: [AvailableXcode]) -> AvailableXcode? {
        availableXcodes
            .filter(\.version.isNotPrerelease)
            .sorted(\.version)
            .last
    }

    /// Returns the newest prerelease Xcode by release date.
    public func latestPrerelease(in availableXcodes: [AvailableXcode]) -> AvailableXcode? {
        availableXcodes
            .filter { $0.version.isPrerelease }
            .filter { $0.releaseDate != nil }
            .sorted { $0.releaseDate! < $1.releaseDate! }
            .last
    }

    private func parsedVersion(
        _ versionString: String,
        versionFileDirectory: Path
    ) throws -> Version {
        if let version = Version(xcodeVersion: versionString) ?? versionFile.version(inDirectory: versionFileDirectory) {
            return version
        }
        throw XcodeInstallResolutionError.invalidVersion(versionString)
    }

    private func ensureNotInstalled(
        _ version: Version,
        installedXcodes: [InstalledXcode],
        willInstall: Bool
    ) throws {
        guard willInstall else { return }
        if let installedXcode = installedXcodes.first(where: { $0.version.isEquivalent(to: version) }) {
            throw XcodeInstallResolutionError.versionAlreadyInstalled(installedXcode)
        }
    }
}
