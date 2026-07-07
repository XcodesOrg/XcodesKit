import XCTest
@testable import XcodesKit

final class RuntimeDecodingTests: XCTestCase {
    func testDownloadableRuntimesResponseDecodesAuthenticationNone() throws {
        let response = try PropertyListDecoder().decode(
            DownloadableRuntimesResponse.self,
            from: Self.plistData(downloadablesBody: """
            <dict>
                <key>category</key>
                <string>simulator</string>
                <key>simulatorVersion</key>
                <dict>
                    <key>buildUpdate</key>
                    <string>22A3362</string>
                    <key>version</key>
                    <string>18.0</string>
                </dict>
                <key>source</key>
                <string>https://example.com/iOS_18_Runtime.dmg</string>
                <key>dictionaryVersion</key>
                <integer>1</integer>
                <key>contentType</key>
                <string>diskImage</string>
                <key>platform</key>
                <string>com.apple.platform.iphoneos</string>
                <key>identifier</key>
                <string>com.apple.CoreSimulator.SimRuntime.iOS-18-0</string>
                <key>version</key>
                <string>18.0</string>
                <key>fileSize</key>
                <integer>42</integer>
                <key>name</key>
                <string>iOS 18.0</string>
                <key>authentication</key>
                <string>none</string>
            </dict>
            """)
        )

        XCTAssertEqual(response.downloadables.count, 1)
        XCTAssertEqual(response.downloadables.first?.authentication, DownloadableRuntime.Authentication.none)
    }

    private static func plistData(downloadablesBody: String) -> Data {
        Data("""
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>sdkToSimulatorMappings</key>
            <array/>
            <key>sdkToSeedMappings</key>
            <array/>
            <key>refreshInterval</key>
            <integer>3600</integer>
            <key>downloadables</key>
            <array>
                \(downloadablesBody)
            </array>
            <key>version</key>
            <string>2</string>
        </dict>
        </plist>
        """.utf8)
    }
}
