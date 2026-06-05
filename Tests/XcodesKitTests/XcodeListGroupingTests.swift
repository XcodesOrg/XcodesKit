import XCTest
@preconcurrency import Path
import Version
@testable import XcodesKit

final class XcodeListGroupingTests: XCTestCase {
    func testGroupsVersionsByMajorAndMinorVersionDescending() throws {
        let items = try [
            item("15.0.1"),
            item("16.1.0"),
            item("16.0.0"),
            item("16.1.1"),
            item("15.2.0")
        ]

        let groups = items.groupedByMajorVersion()

        XCTAssertEqual(groups.map(\.majorVersion), [16, 15])
        XCTAssertEqual(groups[0].minorVersionGroups.map(\.displayName), ["16.1", "16.0"])
        XCTAssertEqual(groups[0].minorVersionGroups[0].versions.map(\.version), [
            try XCTUnwrap(Version("16.1.1")),
            try XCTUnwrap(Version("16.1.0"))
        ])
        XCTAssertEqual(groups[1].minorVersionGroups.map(\.displayName), ["15.2", "15.0"])
    }

    func testGroupRollupsUseLatestReleaseAndInstallationState() throws {
        let installedPath = try XCTUnwrap(Path("/Applications/Xcode-16.0.app"))
        let items = try [
            item("16.1.0-Beta", installState: .notInstalled),
            item("16.0.1", installState: .notInstalled),
            item("16.0.0", installState: .installed(installedPath), selected: true)
        ]

        let group = try XCTUnwrap(items.groupedByMajorVersion().first)
        let minorGroup = try XCTUnwrap(group.minorVersionGroups.first { $0.minorVersion == 0 })

        XCTAssertEqual(group.latestRelease?.version, try XCTUnwrap(Version("16.0.1")))
        XCTAssertEqual(minorGroup.latestRelease?.version, try XCTUnwrap(Version("16.0.1")))
        XCTAssertTrue(group.hasInstalled)
        XCTAssertTrue(minorGroup.hasInstalled)
        XCTAssertEqual(group.selectedVersion?.version, try XCTUnwrap(Version("16.0.0")))
        XCTAssertEqual(minorGroup.selectedVersion?.version, try XCTUnwrap(Version("16.0.0")))
    }

    func testGroupRollupsTrackInstallingVersions() throws {
        let progress = Progress(totalUnitCount: 100)
        let items = try [
            item("16.0.0", installState: .installing(.downloading(progress: progress))),
            item("16.0.1")
        ]

        let group = try XCTUnwrap(items.groupedByMajorVersion().first)
        let minorGroup = try XCTUnwrap(group.minorVersionGroups.first)

        XCTAssertTrue(group.hasInstalling)
        XCTAssertTrue(minorGroup.hasInstalling)
    }

    func testGroupedVersionsHideOlderIdenticalBuildsWhenNewerBuildIsVisible() throws {
        let releaseID = XcodeID(version: try XCTUnwrap(Version("26.5.0+17F76")))
        let releaseCandidateID = XcodeID(version: try XCTUnwrap(Version("26.5.0-Release.Candidate+17F76")))
        let items = try [
            item("26.5.0+17F76", identicalBuilds: [releaseID, releaseCandidateID]),
            item("26.5.0-Release.Candidate+17F76")
        ]

        let versions = try XCTUnwrap(items.groupedByMajorVersion().first?.versions.map(\.version))

        XCTAssertEqual(versions, [try XCTUnwrap(Version("26.5.0+17F76"))])
    }

    func testGroupedVersionsKeepOlderIdenticalBuildsWhenNewerBuildIsFilteredOut() throws {
        let releaseID = XcodeID(version: try XCTUnwrap(Version("26.5.0+17F76")))
        let releaseCandidateID = XcodeID(version: try XCTUnwrap(Version("26.5.0-Release.Candidate+17F76")))
        let items = try [
            item("26.5.0-Release.Candidate+17F76", identicalBuilds: [releaseID, releaseCandidateID])
        ]

        let versions = try XCTUnwrap(items.groupedByMajorVersion().first?.versions.map(\.version))

        XCTAssertEqual(versions, [try XCTUnwrap(Version("26.5.0-Release.Candidate+17F76"))])
    }

    func testGenericGroupedVersionsHideOlderIdenticalBuildsWhenNewerBuildIsVisible() throws {
        let releaseID = XcodeID(version: try XCTUnwrap(Version("26.5.0+17F76")))
        let releaseCandidateID = XcodeID(version: try XCTUnwrap(Version("26.5.0-Release.Candidate+17F76")))
        let items = try [
            PositionedXcodeListItem(position: 0, item: item("26.5.0+17F76", identicalBuilds: [releaseID, releaseCandidateID])),
            PositionedXcodeListItem(position: 1, item: item("26.5.0-Release.Candidate+17F76"))
        ]

        let groups = items.groupedByMajorVersion(item: \.item)

        XCTAssertEqual(groups.first?.versions.map(\.position), [0])
    }

    func testAppliesVersionArchitectureSearchAndInstalledFilters() throws {
        let installedPath = try XCTUnwrap(Path("/Applications/Xcode-16.0.app"))
        let items = try [
            item("16.1.0-Beta", architectures: [.arm64]),
            item("16.0.0", installState: .installed(installedPath), architectures: [.arm64]),
            item("15.0.0", architectures: [.arm64, .x86_64])
        ]

        let filtered = items.applying(XcodeListFilters(
            versionFilter: .release,
            architectureFilters: [.variant(.appleSilicon)],
            searchText: "16",
            installedOnly: true
        ))

        XCTAssertEqual(filtered.map(\.version), [try XCTUnwrap(Version("16.0.0"))])
    }

    func testAllowedMajorVersionsFilterKeepsInstalledOlderVersions() throws {
        let installedPath = try XCTUnwrap(Path("/Applications/Xcode-14.0.app"))
        let items = try [
            item("16.0.0"),
            item("15.0.0"),
            item("14.0.0", installState: .installed(installedPath)),
            item("13.0.0")
        ]

        let filtered = items.filteringUninstalledVersions(allowedMajorVersions: 1)

        XCTAssertEqual(filtered.map(\.version), [
            try XCTUnwrap(Version("16.0.0")),
            try XCTUnwrap(Version("15.0.0")),
            try XCTUnwrap(Version("14.0.0"))
        ])
    }

    func testGenericFilteringAndGroupingPreservesDuplicateIDs() throws {
        let items = try [
            PositionedXcodeListItem(position: 0, item: item("3.2.3+10M2262")),
            PositionedXcodeListItem(position: 1, item: item("3.2.3+10M2262"))
        ]

        let filtered = items.applying(XcodeListFilters(searchText: "3.2.3"), item: \.item)
        let groups = filtered.groupedByMajorVersion(item: \.item)

        XCTAssertEqual(filtered.map(\.position), [0, 1])
        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(groups.first?.versions.map(\.position), [0, 1])
    }

    private func item(
        _ version: String,
        identicalBuilds: [XcodeID] = [],
        installState: XcodeInstallState = .notInstalled,
        selected: Bool = false,
        architectures: [Architecture]? = nil
    ) throws -> XcodeListItem {
        XcodeListItem(
            version: try XCTUnwrap(Version(version)),
            identicalBuilds: identicalBuilds,
            installState: installState,
            selected: selected,
            architectures: architectures
        )
    }
}

private struct PositionedXcodeListItem {
    let position: Int
    let item: XcodeListItem
}
