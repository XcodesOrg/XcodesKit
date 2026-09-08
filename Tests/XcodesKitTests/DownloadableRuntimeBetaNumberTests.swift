import XCTest
@testable import XcodesKit

final class DownloadableRuntimeBetaNumberTests: XCTestCase {
    func testUsesSeedMappingForUUIDRuntime() throws {
        let response = DownloadableRuntimesResponse(
            sdkToSimulatorMappings: [],
            sdkToSeedMappings: [
                SDKToSeedMapping(buildUpdate: "24A5423a", platform: .iOS, seedNumber: 6)
            ],
            refreshInterval: 3600,
            downloadables: [Self.runtime()],
            version: "2"
        )

        let runtime = try XCTUnwrap(response.downloadablesWithSDKBuildUpdates().first)

        XCTAssertEqual(runtime.betaNumber, 6)
        XCTAssertEqual(runtime.completeVersion, "27.0-beta6")
        XCTAssertEqual(runtime.visibleIdentifier, "iOS 27.0-beta6")
    }

    func testUUIDRuntimeFallsBackToNameWithoutMatchingSeedData() {
        let runtime = Self.runtime()

        XCTAssertEqual(runtime.betaNumber, 6)
        XCTAssertNotEqual(runtime.betaNumber, 21)
    }

    func testStableUUIDContainingBFollowedByDigitsIsNotABeta() {
        let runtime = Self.runtime(name: "iOS 27.0 Simulator Runtime")

        XCTAssertNil(runtime.betaNumber)
        XCTAssertEqual(runtime.visibleIdentifier, "iOS 27.0")
    }

    func testLegacyStructuredIdentifierStillProvidesBetaNumber() {
        let runtime = Self.runtime(
            identifier: "com.apple.dmg.iPhoneSimulatorSDK27_0_b3_1",
            name: "iOS 27.0 Simulator Runtime"
        )

        XCTAssertEqual(runtime.betaNumber, 3)
    }

    func testUnnumberedBetaNameRepresentsFirstBeta() {
        let runtime = Self.runtime(
            identifier: "com.apple.dmg.iPhoneSimulatorSDK27_0_b1",
            name: "iOS 27.0 beta Simulator Runtime"
        )

        XCTAssertEqual(runtime.betaNumber, 1)
    }

    func testSeedNumberSurvivesCacheCodingRoundTrip() throws {
        var runtime = Self.runtime()
        runtime.seedNumber = 6

        let data = try JSONEncoder().encode([runtime])
        let decodedRuntime = try XCTUnwrap(JSONDecoder().decode([DownloadableRuntime].self, from: data).first)

        XCTAssertEqual(decodedRuntime.seedNumber, 6)
        XCTAssertEqual(decodedRuntime.betaNumber, 6)
    }

    func testCacheWithoutSeedNumberStillDecodesAndUsesMetadataFallback() throws {
        let data = try JSONEncoder().encode([Self.runtime()])
        let decodedRuntime = try XCTUnwrap(JSONDecoder().decode([DownloadableRuntime].self, from: data).first)

        XCTAssertNil(decodedRuntime.seedNumber)
        XCTAssertEqual(decodedRuntime.betaNumber, 6)
    }

    private static func runtime(
        identifier: String = "0218a56d-df74-59c7-a193-7cb21db4a45b",
        name: String = "iOS 27.0 beta 6 Simulator Runtime"
    ) -> DownloadableRuntime {
        DownloadableRuntime(
            category: .simulator,
            simulatorVersion: .init(buildUpdate: "24A5423a", version: "27.0"),
            source: nil,
            architectures: [.arm64],
            dictionaryVersion: 2,
            contentType: .cryptexDiskImage,
            platform: .iOS,
            identifier: identifier,
            version: "27.0.0.6",
            fileSize: 7_986_041_344,
            hostRequirements: nil,
            name: name,
            authentication: DownloadableRuntime.Authentication.none
        )
    }
}
