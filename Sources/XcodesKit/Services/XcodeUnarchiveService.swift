import Foundation

public enum XcodeUnarchiveError: Error, Equatable, Sendable {
    case damagedXIP(url: URL)
    case notEnoughFreeSpaceToExpandArchive(url: URL)
}

public enum XcodeUnarchiveStep: Equatable, Sendable {
    case unarchiving
    case moving(destination: String)
}

public struct XcodeUnarchiveService: Sendable {
    public typealias Unarchive = @Sendable (URL) async throws -> Void
    public typealias ExtractAEA = @Sendable (_ archive: URL, _ workingDirectory: URL) async throws -> Void
    public typealias FileExists = @Sendable (String) -> Bool
    public typealias MoveItem = @Sendable (URL, URL) async throws -> Void
    public typealias RemoveItem = @Sendable (URL) throws -> Void
    public typealias StepChanged = @Sendable (XcodeUnarchiveStep) async -> Void

    private let unarchive: Unarchive
    private let extractAEA: ExtractAEA
    private let fileExists: FileExists
    private let moveItem: MoveItem
    private let removeItem: RemoveItem

    public init(
        unarchive: @escaping Unarchive,
        fileExists: @escaping FileExists,
        moveItem: @escaping MoveItem,
        removeItem: @escaping RemoveItem,
        extractAEA: @escaping ExtractAEA = XcodesShell().extractXcodeAEA
    ) {
        self.unarchive = unarchive
        self.extractAEA = extractAEA
        self.fileExists = fileExists
        self.moveItem = moveItem
        self.removeItem = removeItem
    }

    public func unarchiveAndMove(
        at source: URL,
        to destination: URL,
        stepChanged: @escaping StepChanged = { _ in }
    ) async throws -> URL {
        if source.pathExtension.lowercased() == "aea" {
            return try await extractAndMoveAEA(at: source, to: destination, stepChanged: stepChanged)
        }
        return try await unarchiveAndMoveXIP(at: source, to: destination, stepChanged: stepChanged)
    }

    private func extractAndMoveAEA(at source: URL, to destination: URL, stepChanged: StepChanged) async throws -> URL {
        await stepChanged(.unarchiving)
        try Task.checkCancellation()

        let files = FileManager.default
        let stagingDirectory = files.temporaryDirectory.appendingPathComponent("Xcodes-AEA-\(UUID())", isDirectory: true)
        try files.createDirectory(at: stagingDirectory, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
        var keepStagedBundle = false
        defer {
            if !keepStagedBundle {
                try? files.removeItem(at: stagingDirectory)
            }
        }

        try await extractAEA(source, stagingDirectory)
        try Task.checkCancellation()
        let bundles = try files.contentsOfDirectory(at: stagingDirectory, includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey])
            .filter { url in
                guard url.pathExtension.lowercased() == "app" else { return false }
                let properties = try url.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
                return properties.isDirectory == true && properties.isSymbolicLink == false
            }
        guard bundles.count == 1, let bundle = bundles.first,
              Bundle(url: bundle)?.bundleIdentifier == "com.apple.dt.Xcode" else {
            throw XcodesKitError("Expected one Xcode app bundle after extracting \(source.lastPathComponent).")
        }

        await stepChanged(.moving(destination: destination.path))
        try Task.checkCancellation()
        do {
            try await moveItem(bundle, destination)
        } catch {
            // The app can offer a manual move command that needs the extracted bundle.
            keepStagedBundle = !(error is CancellationError) && !Task.isCancelled
            throw error
        }
        return destination
    }

    public func unarchiveAndMoveXIP(
        at source: URL,
        to destination: URL,
        stepChanged: @escaping StepChanged = { _ in }
    ) async throws -> URL {
        try await withTaskCancellationHandler {
            try await unarchiveAndMoveXIPWithoutCancellationHandler(
                at: source,
                to: destination,
                stepChanged: stepChanged
            )
        } onCancel: {
            if fileExists(source.path) {
                try? removeItem(source)
            }
            if fileExists(destination.path) {
                try? removeItem(destination)
            }
        }
    }

    private func unarchiveAndMoveXIPWithoutCancellationHandler(
        at source: URL,
        to destination: URL,
        stepChanged: StepChanged
    ) async throws -> URL {
        await stepChanged(.unarchiving)

        do {
            try await unarchive(source)
        } catch {
            if let executionError = error as? ProcessExecutionError {
                if executionError.standardError.contains("damaged and can’t be expanded") {
                    throw XcodeUnarchiveError.damagedXIP(url: source)
                }
                if executionError.standardError.contains("can’t be expanded because the selected volume doesn’t have enough free space.") {
                    throw XcodeUnarchiveError.notEnoughFreeSpaceToExpandArchive(url: source)
                }
            }
            throw error
        }

        await stepChanged(.moving(destination: destination.path))

        let xcodeURL = source.deletingLastPathComponent().appendingPathComponent("Xcode.app")
        let xcodeBetaURL = source.deletingLastPathComponent().appendingPathComponent("Xcode-beta.app")
        if fileExists(xcodeURL.path) {
            try await moveItem(xcodeURL, destination)
        } else if fileExists(xcodeBetaURL.path) {
            try await moveItem(xcodeBetaURL, destination)
        }

        return destination
    }
}
