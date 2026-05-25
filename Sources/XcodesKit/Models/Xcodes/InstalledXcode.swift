import Foundation
@preconcurrency import Path
@preconcurrency import Version

/// A version of Xcode that's already installed.
public struct InstalledXcode: Equatable, Sendable {
    /// Loads file data at a path.
    public typealias ContentsAtPath = @Sendable (String) -> Data?
    /// Loads the architectures supported by an Xcode executable.
    public typealias LoadArchitectures = @Sendable (URL) throws -> ProcessOutput

    /// The path to the Xcode app bundle.
    public let path: Path
    /// The stable identity for this installed Xcode and architecture combination.
    public let xcodeID: XcodeID

    /// Composed of the bundle short version from Info.plist and the product build version from version.plist.
    public var version: Version {
        xcodeID.version
    }

    /// Creates an installed Xcode from known metadata.
    public init(path: Path, version: Version, architectures: [Architecture]? = nil) {
        self.path = path
        self.xcodeID = XcodeID(version: version, architectures: architectures)
    }

    /// Attempts to load installed Xcode metadata from an app bundle path.
    public init?(path: Path) {
        self.init(
            path: path,
            contentsAtPath: { path in Current.files.contents(atPath: path) },
            loadArchitectures: Current.shell.archs
        )
    }

    /// Attempts to load installed Xcode metadata with injected file and architecture readers.
    public init?(
        path: Path,
        contentsAtPath: ContentsAtPath,
        loadArchitectures: LoadArchitectures
    ) {
        guard
            let bundle = XcodeBundleInfo(path: path, contentsAtPath: contentsAtPath),
            bundle.bundleID == "com.apple.dt.Xcode"
        else { return nil }
        self.path = bundle.path

        let xcodeBinaryURL = path.url.appending(path: "Contents/MacOS/Xcode")
        let archsString = try? loadArchitectures(xcodeBinaryURL).out
        let architectures = archsString?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: " ")
            .compactMap { Architecture(rawValue: String($0)) }

        self.xcodeID = XcodeID(version: bundle.version, architectures: architectures)
    }
}

public extension Array where Element == InstalledXcode {
    /// Returns the first installed Xcode that unambiguously has the same version as `version`.
    func first(withVersion version: Version) -> InstalledXcode? {
        XcodeVersionMatcher.find(version: version, in: self, versionKeyPath: \InstalledXcode.version)
    }
}
