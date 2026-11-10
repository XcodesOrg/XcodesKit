import Foundation
@preconcurrency import Path

public struct XcodesShell: Sendable {
    public init() {}

    public var unxip: @Sendable (URL) async throws -> ProcessOutput = {
        try await XcodesProcess.run(Path.root.usr.bin.xip, workingDirectory: $0.deletingLastPathComponent(), "--expand", $0.path)
    }
    public var extractXcodeAEA: @Sendable (URL, URL) async throws -> Void = { archive, workingDirectory in
        let archiveutil = Path.root.usr.bin.archiveutil
        guard FileManager.default.isExecutableFile(atPath: archiveutil.string) else {
            throw XcodesKitError("Installing a .aea archive requires a version of macOS with archiveutil. Update macOS or use a .xip archive if available.")
        }

        do {
            _ = try await XcodesProcess.run(archiveutil, workingDirectory: workingDirectory, "extractXcodeAEA", archive.path)
        } catch let error as ProcessExecutionError {
            let diagnostic = [error.standardError, error.standardOutput]
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .joined(separator: "\n")
            let detail = diagnostic.isEmpty ? "archiveutil exited with status \(error.terminationStatus)." : diagnostic
            throw XcodesKitError("Could not extract \(archive.lastPathComponent): \(detail)")
        }
    }
    public var spctlAssess: @Sendable (URL) async throws -> ProcessOutput = {
        try await XcodesProcess.run(Path.root.usr.sbin.spctl, "--assess", "--verbose", "--type", "execute", $0.path)
    }
    public var codesignVerify: @Sendable (URL) async throws -> ProcessOutput = {
        try await XcodesProcess.run(Path.root.usr.bin.codesign, "-vv", "-d", $0.path)
    }
    public var buildVersion: @Sendable () async throws -> ProcessOutput = {
        try await XcodesProcess.run(Path.root.usr.bin.sw_vers, "-buildVersion")
    }
    public var xcodeBuildVersion: @Sendable (InstalledXcode) async throws -> ProcessOutput = {
        try await XcodesProcess.run(Path.root.usr.libexec.PlistBuddy, "-c", "Print :ProductBuildVersion", "\($0.path.string)/Contents/version.plist")
    }
    public var getUserCacheDir: @Sendable () async throws -> ProcessOutput = {
        try await XcodesProcess.run(Path.root.usr.bin.getconf, "DARWIN_USER_CACHE_DIR")
    }
    public var touchInstallCheck: @Sendable (String, String, String) async throws -> ProcessOutput = {
        try await XcodesProcess.run(Path.root.usr.bin/"touch", "\($0)com.apple.dt.Xcode.InstallCheckCache_\($1)_\($2)")
    }
    public var installedRuntimes: @Sendable () async throws -> ProcessOutput = {
        try await XcodesProcess.run(Path.root.usr.bin.join("xcrun"), "simctl", "runtime", "list", "-j")
    }
    public var mountDmg: @Sendable (URL) async throws -> ProcessOutput = {
        try await XcodesProcess.run(Path.root.usr.bin.join("hdiutil"), "attach", "-nobrowse", "-plist", $0.path)
    }
    public var unmountDmg: @Sendable (URL) async throws -> ProcessOutput = {
        try await XcodesProcess.run(Path.root.usr.bin.join("hdiutil"), "detach", $0.path)
    }
    public var expandPkg: @Sendable (URL, URL) async throws -> ProcessOutput = {
        try await XcodesProcess.run(Path.root.usr.sbin.join("pkgutil"), "--verbose", "--expand", $0.path, $1.path)
    }
    public var createPkg: @Sendable (URL, URL) async throws -> ProcessOutput = {
        try await XcodesProcess.run(Path.root.usr.sbin.join("pkgutil"), "--flatten", $0.path, $1.path)
    }
    public var installPkg: @Sendable (URL, String) async throws -> ProcessOutput = {
        try await XcodesProcess.run(Path.root.usr.sbin.join("installer"), "-pkg", $0.path, "-target", $1)
    }
    public var installRuntimeImage: @Sendable (URL) async throws -> ProcessOutput = {
        try await XcodesProcess.run(Path.root.usr.bin.join("xcrun"), "simctl", "runtime", "add", $0.path)
    }
    public var deleteRuntime: @Sendable (String) async throws -> ProcessOutput = {
        try await XcodesProcess.run(Path.root.usr.bin.join("xcrun"), "simctl", "runtime", "delete", $0)
    }
    public var xcodeSelectPrintPath: @Sendable () async throws -> ProcessOutput = {
        try await XcodesProcess.run(Path.root.usr.bin.join("xcode-select"), "-p")
    }
    public var xcodeSelectSwitch: @Sendable (String?, String) async throws -> ProcessOutput = {
        try await XcodesProcess.sudo(password: $0, Path.root.usr.bin.join("xcode-select"), "-s", $1)
    }

    public var archs: @Sendable (URL) throws -> ProcessOutput = {
        try Process.run(Path.root.usr.bin.join("lipo"), "-archs", $0.path)
    }
}
