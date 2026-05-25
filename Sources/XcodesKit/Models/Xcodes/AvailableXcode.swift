import Foundation
@preconcurrency import Version

/// A version of Xcode that's available for installation.
public struct AvailableXcode: Codable, Equatable, Sendable {
    /// The release version, including prerelease and build metadata when known.
    public var version: Version {
        xcodeID.version
    }

    /// The download URL for the release archive.
    public let url: URL
    /// The archive filename.
    public let filename: String
    /// The release date, when provided by the data source.
    public let releaseDate: Date?
    /// The minimum macOS version required to run this Xcode, when known.
    public let requiredMacOSVersion: String?
    /// The URL for the release notes, when known.
    public let releaseNotesURL: URL?
    /// SDK metadata included in the release.
    public let sdks: SDKs?
    /// Compiler metadata included in the release.
    public let compilers: Compilers?
    /// The download size in bytes, when known.
    public let fileSize: Int64?
    /// The supported host architectures for this archive, when known.
    public let architectures: [Architecture]?
    /// The stable identity for this release and architecture combination.
    public var xcodeID: XcodeID

    /// The path component of the download URL.
    public var downloadPath: String {
        url.path
    }

    /// Creates an available Xcode from release metadata fields.
    public init(
        version: Version,
        url: URL,
        filename: String,
        releaseDate: Date?,
        requiredMacOSVersion: String? = nil,
        releaseNotesURL: URL? = nil,
        sdks: SDKs? = nil,
        compilers: Compilers? = nil,
        fileSize: Int64? = nil,
        architectures: [Architecture]? = nil
    ) {
        self.url = url
        self.filename = filename
        self.releaseDate = releaseDate
        self.requiredMacOSVersion = requiredMacOSVersion
        self.releaseNotesURL = releaseNotesURL
        self.sdks = sdks
        self.compilers = compilers
        self.fileSize = fileSize
        self.architectures = architectures
        self.xcodeID = XcodeID(version: version, architectures: architectures)
    }

    /// Creates an available Xcode from a source-neutral release.
    public init(release: AvailableXcodeRelease) {
        self.init(
            version: release.version,
            url: release.url,
            filename: release.filename,
            releaseDate: release.releaseDate,
            requiredMacOSVersion: release.requiredMacOSVersion,
            releaseNotesURL: release.releaseNotesURL,
            sdks: release.sdks,
            compilers: release.compilers,
            fileSize: release.fileSize,
            architectures: release.architectures
        )
    }

    /// Creates an available Xcode from archive metadata.
    public init(_ archive: XcodeArchive) {
        self.init(
            version: archive.version,
            url: archive.downloadURL,
            filename: archive.filename,
            releaseDate: nil
        )
    }
}

public extension XcodeArchive {
    /// Creates archive metadata from an available Xcode.
    init(_ xcode: AvailableXcode) {
        self.init(
            version: xcode.version,
            downloadURL: xcode.url,
            filename: xcode.filename
        )
    }
}

public extension Array where Element == AvailableXcode {
    /// Returns the first Xcode that unambiguously has the same version as `version`.
    ///
    /// If there's an exact match that takes prerelease identifiers into account, that's returned.
    /// Otherwise, if a version without prerelease or build metadata identifiers is provided, and there's a single match based on only the major, minor and patch numbers, that's returned.
    /// If there are multiple matches, or no matches, nil is returned.
    func first(withVersion version: Version) -> AvailableXcode? {
        XcodeVersionMatcher.find(version: version, in: self, versionKeyPath: \AvailableXcode.version)
    }

    /// Returns Xcodes that include at least one of the requested architectures.
    func matchingArchitectures(_ architectures: [Architecture]) -> [AvailableXcode] {
        guard !architectures.isEmpty else { return self }
        return filter { $0.architectures?.containsAny(architectures) == true }
    }

    /// Returns Xcodes that match all requested architecture filters.
    func matchingArchitectureFilters(_ filters: [ArchitectureFilter]) -> [AvailableXcode] {
        guard !filters.isEmpty else { return self }
        return filter { filters.matches($0.architectures) }
    }

    /// Returns the best compatible Xcode for the given version and host architecture.
    /// Adapted from XcodesOrg/xcodes#470 by wmehanna.
    func firstCompatible(withVersion version: Version, hostArchitecture: Architecture) -> AvailableXcode? {
        let matches = all(withVersion: version)
        guard !matches.isEmpty else { return nil }

        if let universal = matches.first(where: { $0.architectures?.isUniversal == true }) {
            return universal
        }

        if let matching = matches.first(where: { $0.architectures?.contains(hostArchitecture) == true }) {
            return matching
        }

        return matches.first
    }

    private func all(withVersion version: Version) -> [AvailableXcode] {
        let equivalentMatches = filter { $0.version.isEquivalent(to: version) }
        if !equivalentMatches.isEmpty {
            return equivalentMatches
        }

        if version.prereleaseIdentifiers.isEmpty && version.buildMetadataIdentifiers.isEmpty {
            return filter { $0.version.isEqualWithoutAllIdentifiers(to: version) }
        }

        return []
    }
}
