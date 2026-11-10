import Foundation
@preconcurrency import Path
import Version
import XCTest
@testable import XcodesKit

final class XcodeAEAArchiveTests: XCTestCase {
    func testAppleReleaseCatalogAcceptsAEA() async throws {
        let data = Data("""
            {
              "resultCode": 0,
              "downloads": [{
                "name": "Xcode 27.3",
                "dateModified": "11/03/26 12:00",
                "files": [
                  {"remotePath": "/Developer_Tools/Xcode_27.3/not-aea"},
                  {"remotePath": "/Developer_Tools/Xcode_27.3/Xcode_27.3.AEA", "fileSize": 1024}
                ]
              }]
            }
            """.utf8)
        let releases = try await listService(data).releasedXcodes()
        let release = try XCTUnwrap(releases.first)
        XCTAssertEqual(release.filename, "Xcode_27.3.AEA")
        XCTAssertEqual(release.url.absoluteString, "https://download.developer.apple.com/Developer_Tools/Xcode_27.3/Xcode_27.3.AEA")
        XCTAssertEqual(release.fileSize, 1024)
    }

    func testApplePrereleaseCatalogUsesExtensionOfDecodedDownloadPath() throws {
        let data = Data("""
            <div>
                <h2>Xcode 27.3 beta</h2>
                <ul><li>Build 27C5020n</li><li>Released November 3, 2026</li></ul>
                <a class="direct-download" href="/get?path=/Xcode.aea.txt">Not an archive</a>
                <a class="direct-download" href="/get?path=%2FDeveloper_Tools%2FXcode%2027.3%20beta.AEA&amp;other=1">Download</a>
            </div>
            """.utf8)
        let releases = try XcodeListService.parsePrereleaseXcodes(from: data)
        let release = try XCTUnwrap(releases.first)
        XCTAssertEqual(release.filename, "Xcode 27.3 beta.AEA")
        XCTAssertEqual(release.url.absoluteString, "https://developer.apple.com/get?path=%2FDeveloper_Tools%2FXcode%2027.3%20beta.AEA&other=1")
    }

    func testCommunityCatalogPreservesAEAURLAndDownloadUsesSeparateCacheAndResumeData() async throws {
        let archiveURL = "https://developer.apple.com/services-account/download?path=%2FTools%2FXcode.aea&other=1"
        let data = Data("""
            [{
                "name": "Xcode",
                "version": {"number": "27.3", "release": {"release": true}},
                "date": {"year": 2026, "month": 11, "day": 3},
                "requires": "26.6",
                "links": {"download": {"url": "\(archiveURL)"}}
            }]
            """.utf8)
        let releases = try await listService(data).xcodeReleases()
        let release = try XCTUnwrap(releases.first)
        XCTAssertEqual(release.url.absoluteString, archiveURL)
        let archive = XcodeArchive(version: release.version, downloadURL: release.url, filename: release.filename)
        let xip = XcodeArchive(version: release.version, downloadURL: release.url, filename: "Xcode.xip")
        let directory = try XCTUnwrap(Path("/tmp/xcodes"))
        let expected = directory/"Xcode-27.3.0.aea"
        let service = XcodeArchiveService(
            applicationSupportPath: directory,
            fileExists: { $0 == directory/"Xcode-27.3.0.xip" },
            download: { archive, destination, _, _ in
                XCTAssertEqual(archive.downloadURL.absoluteString, archiveURL)
                XCTAssertEqual(destination, expected)
                return destination.url
            }
        )
        let downloaded = try await service.archiveURL(for: archive, downloader: .urlSession) { _ in }
        XCTAssertEqual(downloaded, expected.url)
        XCTAssertEqual(ArchiveDownloadService.resumeDataPath(for: archive, in: directory), directory/"Xcode-27.3.0.aea.resumedata")
        XCTAssertEqual(ArchiveDownloadService.resumeDataPath(for: xip, in: directory), directory/"Xcode-27.3.0.resumedata")
    }

    func testAEAInstallUsesStagedBundleAndRunsExistingValidationAndArchiveCleanup() async throws {
        let fixture = try ArchiveFixture()
        defer { fixture.cleanUp() }
        let xcode = AvailableXcode(version: Version("27.3.0")!, url: fixture.archive, filename: fixture.archive.lastPathComponent, releaseDate: nil)
        let service = XcodeArchiveInstallService(
            destinationDirectory: try XCTUnwrap(Path(url: fixture.directory)),
            unarchiveService: fixture.unarchiveService { source, stage in
                XCTAssertEqual(source, fixture.archive)
                try Self.makeXcodeBundle(in: stage)
            },
            validationService: XcodeValidationService(
                assessSecurity: { url in
                    XCTAssertEqual(url.path, fixture.destination.path)
                    return (0, "", "")
                },
                verifyCodesign: { url in
                    XCTAssertEqual(url.path, fixture.destination.path)
                    return (0, "", """
                        Identifier=com.apple.dt.Xcode
                        Authority=Software Signing
                        Authority=Apple Code Signing Certification Authority
                        Authority=Apple Root CA
                        TeamIdentifier=59GAB85EFG
                        """)
                }
            ),
            fileExists: { FileManager.default.fileExists(atPath: $0) },
            makeInstalledXcode: { InstalledXcode(path: $0, version: xcode.version) }
        )

        let installed = try await service.installArchivedXcode(xcode, at: fixture.archive) {
            XCTAssertEqual($0, fixture.archive)
            try FileManager.default.removeItem(at: $0)
        }
        XCTAssertEqual(installed.path.string, fixture.destination.path)
        XCTAssertFalse(FileManager.default.fileExists(atPath: fixture.archive.path))
        try await fixture.assertStagingCleaned()
    }

    func testAEAExtractionFailureAndInvalidOutputCleanStagingAndPreserveArchive() async throws {
        for failExtraction in [true, false] {
            let fixture = try ArchiveFixture()
            defer { fixture.cleanUp() }
            let service = fixture.unarchiveService { _, stage in
                try Self.makeXcodeBundle(in: stage)
                if failExtraction { throw XcodesKitError("Archive is damaged") }
                try Self.makeXcodeBundle(in: stage, named: "Other-Xcode.app")
            }
            do {
                _ = try await service.unarchiveAndMove(at: fixture.archive, to: fixture.destination)
                XCTFail("Expected extraction to fail")
            } catch let error as XcodesKitError {
                let message = failExtraction ? "Archive is damaged" : "Expected one Xcode app bundle"
                XCTAssertTrue(error.message.hasPrefix(message))
            }
            XCTAssertTrue(FileManager.default.fileExists(atPath: fixture.archive.path))
            XCTAssertFalse(FileManager.default.fileExists(atPath: fixture.destination.path))
            try await fixture.assertStagingCleaned()
        }
    }

    func testAEACancellationCleansStagingAndPreservesArchive() async throws {
        let fixture = try ArchiveFixture()
        defer { fixture.cleanUp() }
        let service = fixture.unarchiveService { _, stage in
            try Self.makeXcodeBundle(in: stage)
            withUnsafeCurrentTask { $0?.cancel() }
        }
        do {
            _ = try await Task {
                try await service.unarchiveAndMove(at: fixture.archive, to: fixture.destination)
            }.value
            XCTFail("Expected cancellation")
        } catch is CancellationError {}
        XCTAssertTrue(FileManager.default.fileExists(atPath: fixture.archive.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: fixture.destination.path))
        try await fixture.assertStagingCleaned()
    }

    func testAEAMoveFailurePreservesBundleForRecovery() async throws {
        let fixture = try ArchiveFixture()
        defer { fixture.cleanUp() }
        let service = fixture.unarchiveService(extract: { _, stage in
            try Self.makeXcodeBundle(in: stage)
        }, move: { _, _ in throw XcodesKitError("Move failed") })
        do {
            _ = try await service.unarchiveAndMove(at: fixture.archive, to: fixture.destination)
            XCTFail("Expected the move to fail")
        } catch let error as XcodesKitError {
            XCTAssertEqual(error.message, "Move failed")
        }
        let stage = try await fixture.stagingDirectory()
        defer { try? FileManager.default.removeItem(at: stage) }
        XCTAssertTrue(FileManager.default.fileExists(atPath: stage.appendingPathComponent("Xcode-beta.app").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: fixture.archive.path))
    }

    func testProcessCancellationWaitsUntilExtractorExits() async throws {
        let fixture = try ArchiveFixture()
        defer { fixture.cleanUp() }
        let pidFile = fixture.directory.appendingPathComponent("pid")
        let task = Task {
            try await XcodesProcess.run(
                URL(fileURLWithPath: "/bin/sh"),
                ["-c", #"printf '%s\n' "$$" > "$1"; exec /bin/sleep 30"#, "sh", pidFile.path]
            )
        }
        defer { task.cancel() }

        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: .seconds(5))
        var pid: Int32?
        while pid == nil && clock.now < deadline {
            if let text = try? String(contentsOf: pidFile, encoding: .utf8) {
                pid = Int32(text.trimmingCharacters(in: .whitespacesAndNewlines))
            }
            if pid == nil { try await Task.sleep(for: .milliseconds(20)) }
        }
        let processID = try XCTUnwrap(pid)
        task.cancel()
        do {
            _ = try await task.value
            XCTFail("Expected cancellation")
        } catch is CancellationError {}
        XCTAssertEqual(kill(processID, 0), -1, "The child must exit before staging is removed")
    }

    func testCancelledTaskDoesNotLaunchExtractor() async throws {
        let fixture = try ArchiveFixture()
        defer { fixture.cleanUp() }
        let marker = fixture.directory.appendingPathComponent("launched")
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try await XcodesProcess.run(URL(fileURLWithPath: "/usr/bin/touch"), [marker.path])
        }
        do {
            _ = try await task.value
            XCTFail("Expected cancellation")
        } catch is CancellationError {}
        XCTAssertFalse(FileManager.default.fileExists(atPath: marker.path))
    }

    private func listService(_ data: Data) -> XcodeListService {
        XcodeListService { request in
            (data, URLResponse(url: request.url!, mimeType: nil, expectedContentLength: data.count, textEncodingName: nil))
        }
    }

    private static func makeXcodeBundle(in stage: URL, named name: String = "Xcode-beta.app") throws {
        let contents = stage.appendingPathComponent("\(name)/Contents")
        try FileManager.default.createDirectory(at: contents, withIntermediateDirectories: true)
        let info = try PropertyListSerialization.data(fromPropertyList: ["CFBundleIdentifier": "com.apple.dt.Xcode"], format: .xml, options: 0)
        try info.write(to: contents.appendingPathComponent("Info.plist"))
    }
}

private struct ArchiveFixture: Sendable {
    private actor StagingRecorder {
        private(set) var directory: URL?
        func record(_ directory: URL) { self.directory = directory }
    }

    let directory: URL
    let archive: URL
    let destination: URL
    private let staging = StagingRecorder()

    init() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        archive = directory.appendingPathComponent("Xcode.AEA")
        destination = directory.appendingPathComponent("Xcode-27.3.0.app")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        try Data().write(to: archive)
    }

    func unarchiveService(
        extract: @escaping XcodeUnarchiveService.ExtractAEA,
        move: @escaping XcodeUnarchiveService.MoveItem = { try FileManager.default.moveItem(at: $0, to: $1) }
    ) -> XcodeUnarchiveService {
        XcodeUnarchiveService(
            unarchive: { _ in XCTFail("AEA must bypass unxip") },
            fileExists: { FileManager.default.fileExists(atPath: $0) },
            moveItem: move,
            removeItem: { try FileManager.default.removeItem(at: $0) },
            extractAEA: { source, directory in
                await staging.record(directory)
                try await extract(source, directory)
            }
        )
    }

    func stagingDirectory() async throws -> URL {
        let directory = await staging.directory
        return try XCTUnwrap(directory)
    }

    func assertStagingCleaned() async throws {
        let directory = try await stagingDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        XCTAssertFalse(FileManager.default.fileExists(atPath: directory.path))
    }

    func cleanUp() {
        try? FileManager.default.removeItem(at: directory)
    }
}
