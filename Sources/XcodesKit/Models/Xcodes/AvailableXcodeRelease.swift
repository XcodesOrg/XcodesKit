import Foundation
@preconcurrency import Version

/// A source-neutral Xcode release that can be mapped into app- or CLI-specific state.
public struct AvailableXcodeRelease: Codable, Sendable {
    /// The release version, including prerelease and build metadata when known.
    public let version: Version
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

    /// The path component of the download URL.
    public var downloadPath: String {
        url.path
    }

    /// Creates source-neutral release metadata.
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
        self.version = version
        self.url = url
        self.filename = filename
        self.releaseDate = releaseDate
        self.requiredMacOSVersion = requiredMacOSVersion
        self.releaseNotesURL = releaseNotesURL
        self.sdks = sdks
        self.compilers = compilers
        self.fileSize = fileSize
        self.architectures = architectures
    }
}
