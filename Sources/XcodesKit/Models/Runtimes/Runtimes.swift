import Foundation

/// Builds a display version string for a simulator runtime.
public func makeRuntimeVersion(for osVersion: String, betaNumber: Int?) -> String {
    let betaSuffix = betaNumber.flatMap { "-beta\($0)" } ?? ""
    return osVersion + betaSuffix
}

/// The decoded response from Apple's downloadable simulator runtime index.
public struct DownloadableRuntimesResponse: Codable, Sendable {
    public let sdkToSimulatorMappings: [SDKToSimulatorMapping]
    public let sdkToSeedMappings: [SDKToSeedMapping]
    public let refreshInterval: Int
    @LossyArray public var downloadables: [DownloadableRuntime]
    public let version: String

    public init(
        sdkToSimulatorMappings: [SDKToSimulatorMapping],
        sdkToSeedMappings: [SDKToSeedMapping],
        refreshInterval: Int,
        downloadables: [DownloadableRuntime],
        version: String
    ) {
        self.sdkToSimulatorMappings = sdkToSimulatorMappings
        self.sdkToSeedMappings = sdkToSeedMappings
        self.refreshInterval = refreshInterval
        self._downloadables = LossyArray(wrappedValue: downloadables)
        self.version = version
    }
}

/// A simulator runtime that is available to download and install.
public struct DownloadableRuntime: Codable, Identifiable, Hashable, Sendable {
    public let category: Category
    public let simulatorVersion: SimulatorVersion
    public let source: String?
    public let architectures: [Architecture]?
    public let dictionaryVersion: Int
    public let contentType: ContentType
    public let platform: Platform
    public let identifier: String
    public let version: String
    public let fileSize: Int
    public let hostRequirements: HostRequirements?
    public let name: String
    public let authentication: Authentication?
    /// The download URL for the runtime, if Apple provided one.
    public var url: URL? {
        if let source {
            return URL(string: source)!
        }
        return nil
    }
    /// The path component of the runtime download URL.
    public var downloadPath: String? {
        url?.path
    }
    
    // dynamically updated - not decoded
    /// Runtime installation state supplied by the host app after decoding.
    public var installState: RuntimeInstallState = .notInstalled
    /// SDK build updates that map to this simulator runtime.
    public var sdkBuildUpdate: [String]?
    
    enum CodingKeys: CodingKey {
        case category
        case simulatorVersion
        case source
        case dictionaryVersion
        case contentType
        case platform
        case identifier
        case version
        case fileSize
        case hostRequirements
        case name
        case authentication
        case sdkBuildUpdate
        case architectures
    }

    /// The beta seed number parsed from the runtime identifier, when present.
    public var betaNumber: Int? {
        enum Regex { static let shared = try! NSRegularExpression(pattern: "b[0-9]+") }
        guard var foundString = Regex.shared.firstString(in: identifier) else { return nil }
        foundString.removeFirst()
        return Int(foundString)!
    }

    /// The OS version plus beta suffix when this is a beta runtime.
    public var completeVersion: String {
        makeRuntimeVersion(for: simulatorVersion.version, betaNumber: betaNumber)
    }

    /// A human-readable identifier such as `iOS 17.5`.
    public var visibleIdentifier: String {
        return platform.shortName + " " + completeVersion
    }
    
    /// Builds a display version string for the provided OS version and beta number.
    public func makeVersion(for osVersion: String, betaNumber: Int?) -> String {
        makeRuntimeVersion(for: osVersion, betaNumber: betaNumber)
    }
    
    /// The formatted download size.
    public var downloadFileSizeString: String {
        return ByteCountFormatter.string(fromByteCount: Int64(fileSize), countStyle: .file)
    }
    
    public var id: String {
        return visibleIdentifier
    }
    
    public static func == (lhs: DownloadableRuntime, rhs: DownloadableRuntime) -> Bool {
        return lhs.identifier == rhs.identifier
    }
}

/// Maps an SDK build update to a beta seed number.
public struct SDKToSeedMapping: Codable, Sendable {
    public let buildUpdate: String
    public let platform: DownloadableRuntime.Platform
    public let seedNumber: Int
}

/// Maps an SDK build update to simulator runtime build updates.
public struct SDKToSimulatorMapping: Codable, Sendable {
    public let sdkBuildUpdate: String
    public let simulatorBuildUpdate: String
    public let sdkIdentifier: String
    public let downloadableIdentifiers: [String]?
}

extension DownloadableRuntime {
    /// Version information for a downloadable simulator runtime.
    public struct SimulatorVersion: Codable, Hashable, Sendable {
        public let buildUpdate: String
        public let version: String
    }

    /// Host OS and Xcode requirements for a downloadable runtime.
    public struct HostRequirements: Codable, Hashable, Sendable {
        public let maxHostVersion: String?
        public let excludedHostArchitectures: [String]?
        public let minHostVersion: String?
        public let minXcodeVersion: String?
    }

    /// Authentication mode required by the runtime download.
    public enum Authentication: String, Codable, Sendable {
        case virtual = "virtual"
        case none = "none"
    }

    /// The downloadable content category.
    public enum Category: String, Codable, Sendable {
        case simulator = "simulator"
    }

    /// The artifact format used to distribute the runtime.
    public enum ContentType: String, Codable, Sendable {
        case diskImage = "diskImage"
        case package = "package"
        case cryptexDiskImage = "cryptexDiskImage"
        case patchableCryptexDiskImage = "patchableCryptexDiskImage"
    }

    /// The Apple platform targeted by a downloadable runtime.
    public enum Platform: String, Codable, Sendable {
        case iOS = "com.apple.platform.iphoneos"
        case macOS = "com.apple.platform.macosx"
        case watchOS = "com.apple.platform.watchos"
        case tvOS = "com.apple.platform.appletvos"
        case visionOS = "com.apple.platform.xros"
        
        /// Presentation sort order for platforms.
        public var order: Int {
            switch self {
                case .iOS: return 1
                case .macOS: return 2
                case .watchOS: return 3
                case .tvOS: return 4
                case .visionOS: return 5
            }
        }

        /// A short display name such as `iOS` or `watchOS`.
        public var shortName: String {
            switch self {
                case .iOS: return "iOS"
                case .macOS: return "macOS"
                case .watchOS: return "watchOS"
                case .tvOS: return "tvOS"
                case .visionOS: return "visionOS"
            }
        }
        
    }
}

/// A simulator runtime currently installed on the machine.
public struct InstalledRuntime: Decodable, Sendable {
    public let build: String
    public let deletable: Bool
    public let identifier: UUID
    public let kind: Kind
    public let lastUsedAt: Date?
    public let path: String
    public let platformIdentifier: Platform
    public let runtimeBundlePath: String
    public let runtimeIdentifier: String
    public let signatureState: String
    public let state: String
    public let version: String
    public let sizeBytes: Int?
    public let supportedArchitectures: [Architecture]?
}

public extension Array where Element == DownloadableRuntime {
    /// Returns runtimes that include at least one of the requested architectures.
    func matchingArchitectures(_ architectures: [Architecture]) -> [DownloadableRuntime] {
        guard !architectures.isEmpty else { return self }
        return filter { $0.architectures?.containsAny(architectures) == true }
    }

    /// Returns runtimes that match all requested architecture filters.
    func matchingArchitectureFilters(_ filters: [ArchitectureFilter]) -> [DownloadableRuntime] {
        guard !filters.isEmpty else { return self }
        return filter { filters.matches($0.architectures) }
    }
}

extension InstalledRuntime {
    /// The installation mechanism or origin for an installed runtime.
    public enum Kind: String, Decodable, Sendable {
        case bundled = "Bundled with Xcode"
        case cryptexDiskImage = "Cryptex Disk Image"
        case diskImage = "Disk Image"
        case legacyDownload = "Legacy Download"
        case patchableCryptexDiskImage = "Patchable Cryptex Disk Image"
    }

    /// The simulator platform identifier reported by CoreSimulator.
    public enum Platform: String, Decodable, Sendable {
        case tvOS = "com.apple.platform.appletvsimulator"
        case iOS = "com.apple.platform.iphonesimulator"
        case watchOS = "com.apple.platform.watchsimulator"
        case visionOS = "com.apple.platform.xrsimulator"
        
        /// Converts the CoreSimulator platform identifier to the downloadable runtime platform.
        public var asPlatformOS: DownloadableRuntime.Platform {
            switch self {
                case .watchOS: return .watchOS
                case .iOS: return .iOS
                case .tvOS: return .tvOS
                case .visionOS: return .visionOS
            }
        }
    }
}
