import XCTest
@testable import XcodesKit

final class RuntimeDecodingLossyArrayTests: XCTestCase {
    func testDownloadableRuntimesResponseSkipsUndecodableDownloadables() throws {
        let response = try PropertyListDecoder().decode(
            DownloadableRuntimesResponse.self,
            from: Self.plistData(downloadablesBody: """
            <dict>
                <key>category</key>
                <string>simulator</string>
                <key>simulatorVersion</key>
                <dict>
                    <key>buildUpdate</key>
                    <string>20A360</string>
                    <key>version</key>
                    <string>16.0</string>
                </dict>
                <key>source</key>
                <string>https://example.com/iOS_16_Runtime.dmg</string>
                <key>dictionaryVersion</key>
                <integer>1</integer>
                <key>contentType</key>
                <string>diskImage</string>
                <key>platform</key>
                <string>com.apple.platform.iphoneos</string>
                <key>identifier</key>
                <string>com.apple.CoreSimulator.SimRuntime.iOS-16-0</string>
                <key>version</key>
                <string>16.0</string>
                <key>fileSize</key>
                <integer>42</integer>
                <key>name</key>
                <string>iOS 16.0</string>
                <key>authentication</key>
                <string>virtual</string>
            </dict>
            <dict>
                <key>category</key>
                <string>simulator</string>
                <key>simulatorVersion</key>
                <dict>
                    <key>buildUpdate</key>
                    <string>20A361</string>
                    <key>version</key>
                    <string>16.1</string>
                </dict>
                <key>source</key>
                <string>https://example.com/iOS_16_1_Runtime.dmg</string>
                <key>dictionaryVersion</key>
                <integer>1</integer>
                <key>contentType</key>
                <string>unknownType</string>
                <key>platform</key>
                <string>com.apple.platform.iphoneos</string>
                <key>identifier</key>
                <string>com.apple.CoreSimulator.SimRuntime.iOS-16-1</string>
                <key>version</key>
                <string>16.1</string>
                <key>fileSize</key>
                <integer>43</integer>
                <key>name</key>
                <string>iOS 16.1</string>
                <key>authentication</key>
                <string>virtual</string>
            </dict>
            """)
        )

        XCTAssertEqual(response.downloadables.count, 1)
        XCTAssertEqual(response.downloadables.first?.identifier, "com.apple.CoreSimulator.SimRuntime.iOS-16-0")
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
