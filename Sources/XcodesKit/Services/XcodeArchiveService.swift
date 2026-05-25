import Foundation
@preconcurrency import Path
@preconcurrency import Version

/// A downloadable or local Xcode archive.
public struct XcodeArchive: Sendable {
    /// The Xcode version contained in the archive.
    public let version: Version
    /// The URL used to download or read the archive.
    public let downloadURL: URL
    /// The archive filename, including its extension.
    public let filename: String

    /// Creates archive metadata for an Xcode download or local archive file.
    public init(version: Version, downloadURL: URL, filename: String) {
        self.version = version
        self.downloadURL = downloadURL
        self.filename = filename
    }
}

/// The download implementation used for Xcode archives.
public enum XcodeArchiveDownloader: String, CaseIterable, Identifiable, CustomStringConvertible, Sendable {
    /// Download archives with URLSession.
    case urlSession
    /// Download archives with aria2.
    case aria2

    public var id: Self { self }

    public var description: String {
        switch self {
        case .urlSession: return "URLSession"
        case .aria2: return "aria2"
        }
    }
}

/// Locates existing Xcode archives or downloads them into application support storage.
public struct XcodeArchiveService: Sendable {
    /// Downloads an Xcode archive and reports progress.
    public typealias Download = @Sendable (XcodeArchive, Path, XcodeArchiveDownloader, @escaping @Sendable (Progress) -> Void) async throws -> URL

    private let applicationSupportPath: Path
    private let fileExists: @Sendable (Path) -> Bool
    private let download: Download

    /// Creates a service with injected storage and download behavior.
    public init(
        applicationSupportPath: Path,
        fileExists: @escaping @Sendable (Path) -> Bool,
        download: @escaping Download
    ) {
        self.applicationSupportPath = applicationSupportPath
        self.fileExists = fileExists
        self.download = download
    }

    /// Returns a usable archive URL, reusing an existing completed archive when possible.
    public func archiveURL(
        for archive: XcodeArchive,
        downloader: XcodeArchiveDownloader,
        progressChanged: @escaping @Sendable (Progress) -> Void
    ) async throws -> URL {
        if let existingArchiveURL = existingArchiveURL(for: archive, downloader: downloader) {
            return existingArchiveURL
        }

        return try await download(archive, expectedArchivePath(for: archive), downloader, progressChanged)
    }

    /// Returns the existing archive URL if a completed archive is already present.
    public func existingArchiveURL(
        for archive: XcodeArchive,
        downloader: XcodeArchiveDownloader
    ) -> URL? {
        let destination = expectedArchivePath(for: archive)
        let metadataPath = aria2MetadataPath(for: destination)
        let aria2DownloadIsIncomplete = downloader == .aria2 && fileExists(metadataPath)

        if fileExists(destination), aria2DownloadIsIncomplete == false {
            return destination.url
        }

        return nil
    }

    /// Returns the destination path used for an archive in application support storage.
    public func expectedArchivePath(for archive: XcodeArchive) -> Path {
        applicationSupportPath/"Xcode-\(archive.version).\(archive.filename.suffix(fromLast: "."))"
    }

    /// Returns aria2's metadata sidecar path for a destination archive path.
    public func aria2MetadataPath(for archivePath: Path) -> Path {
        archivePath.parent/(archivePath.basename() + ".aria2")
    }
}
