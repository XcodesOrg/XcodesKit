import Foundation
@preconcurrency import Path
@preconcurrency import Version

/// A UI-ready Xcode row composed from available and installed Xcode data.
public struct XcodeListItem: Identifiable, Sendable {
    /// The Xcode version represented by this list item.
    public var version: Version {
        id.version
    }

    /// IDs for release and prerelease rows that share the same build.
    public let identicalBuilds: [XcodeID]
    /// The current install state for this Xcode.
    public let installState: XcodeInstallState
    /// Whether this Xcode is currently selected.
    public let selected: Bool
    /// The minimum macOS version required to run this Xcode, when known.
    public let requiredMacOSVersion: String?
    /// The URL for release notes, when known.
    public let releaseNotesURL: URL?
    /// The release date, when known.
    public let releaseDate: Date?
    /// SDK metadata included in the release.
    public let sdks: SDKs?
    /// Compiler metadata included in the release.
    public let compilers: Compilers?
    /// The download size in bytes, when known.
    public let downloadFileSize: Int64?
    /// The supported host architectures for this Xcode, when known.
    public let architectures: [Architecture]?
    /// The stable identity for this version and architecture combination.
    public let id: XcodeID

    /// Creates a composed Xcode list item.
    public init(
        version: Version,
        identicalBuilds: [XcodeID] = [],
        installState: XcodeInstallState,
        selected: Bool,
        requiredMacOSVersion: String? = nil,
        releaseNotesURL: URL? = nil,
        releaseDate: Date? = nil,
        sdks: SDKs? = nil,
        compilers: Compilers? = nil,
        downloadFileSize: Int64? = nil,
        architectures: [Architecture]? = nil
    ) {
        self.identicalBuilds = identicalBuilds
        self.installState = installState
        self.selected = selected
        self.requiredMacOSVersion = requiredMacOSVersion
        self.releaseNotesURL = releaseNotesURL
        self.releaseDate = releaseDate
        self.sdks = sdks
        self.compilers = compilers
        self.downloadFileSize = downloadFileSize
        self.architectures = architectures
        self.id = XcodeID(version: version, architectures: architectures)
    }

    /// The installed bundle path when this item is installed.
    public var installedPath: Path? {
        installState.installedPath
    }

    /// The formatted download size.
    public var downloadFileSizeString: String? {
        downloadFileSize.map {
            ByteCountFormatter.string(fromByteCount: $0, countStyle: .file)
        }
    }
}
