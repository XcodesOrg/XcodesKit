import Foundation
@preconcurrency import Version

/// A stable identifier for an Xcode version and architecture combination.
public struct XcodeID: Codable, Hashable, Identifiable, Sendable {
    /// The Xcode version.
    public let version: Version
    /// The supported host architectures, when the archive is architecture-specific.
    public let architectures: [Architecture]?

    /// A string identifier composed from the version and architectures.
    public var id: String {
        let architectures = architectures?.map(\.rawValue).joined() ?? ""
        return version.description + architectures
    }

    /// Creates an Xcode identifier.
    public init(version: Version, architectures: [Architecture]? = nil) {
        self.version = version
        self.architectures = architectures
    }
}
