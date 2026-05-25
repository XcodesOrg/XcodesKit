import Foundation

/// Removes installed Xcode bundles.
public struct XcodeUninstallService: Sendable {
    /// The result of uninstalling an Xcode.
    public struct Result: Equatable, Sendable {
        /// The Xcode that was uninstalled.
        public let xcode: InstalledXcode
        /// The trash location when the Xcode was moved to the Trash, or nil when it was deleted immediately.
        public let trashURL: URL?

        /// Whether the bundle was deleted immediately instead of moved to the Trash.
        public var didDeleteImmediately: Bool {
            trashURL == nil
        }
    }

    private let removeItem: @Sendable (URL) throws -> Void
    private let trashItem: @Sendable (URL) throws -> URL

    /// Creates an uninstall service with injectable delete and trash operations.
    public init(
        removeItem: @escaping @Sendable (URL) throws -> Void = { try FileManager.default.removeItem(at: $0) },
        trashItem: @escaping @Sendable (URL) throws -> URL = { try FileManager.default.xcodesTrashItem(at: $0) }
    ) {
        self.removeItem = removeItem
        self.trashItem = trashItem
    }

    /// Uninstalls an Xcode by deleting it immediately or moving it to the Trash.
    public func uninstall(_ xcode: InstalledXcode, emptyTrash: Bool) throws -> Result {
        if emptyTrash {
            try removeItem(xcode.path.url)
            return Result(xcode: xcode, trashURL: nil)
        }

        return Result(xcode: xcode, trashURL: try trashItem(xcode.path.url))
    }
}
