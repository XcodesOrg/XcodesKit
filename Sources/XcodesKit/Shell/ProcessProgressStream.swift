import Foundation
import os

final class ProcessProgressStreamRunner: Sendable {
    typealias OutputHandler = @Sendable (String, Progress) -> Void
    typealias FailureHandler = @Sendable (Process, String, String) -> Error
    typealias SuccessHandler = @Sendable () -> Error?

    private let process: Process
    private let progress: Progress
    private let outputHandler: OutputHandler
    private let failureHandler: FailureHandler
    private let successHandler: SuccessHandler
    private let continuation = OSAllocatedUnfairLock<AsyncThrowingStream<Progress, Error>.Continuation?>(initialState: nil)

    init(
        process: Process,
        progress: Progress,
        outputHandler: @escaping OutputHandler,
        failureHandler: @escaping FailureHandler,
        successHandler: @escaping SuccessHandler = { nil }
    ) {
        self.process = process
        self.progress = progress
        self.outputHandler = outputHandler
        self.failureHandler = failureHandler
        self.successHandler = successHandler
    }

    func stream() -> AsyncThrowingStream<Progress, Error> {
        let (stream, continuation) = AsyncThrowingStream.makeStream(of: Progress.self, throwing: Error.self)
        self.continuation.withLock {
            $0 = continuation
        }

        continuation.onTermination = { _ in
            self.cancel()
        }

        start()

        return stream
    }

    private func start() {
        progress.kind = .file
        progress.fileOperationKind = .downloading
        continuation.withLock {
            _ = $0?.yield(progress)
        }

        let stdOutPipe = Pipe()
        process.standardOutput = stdOutPipe
        let stdErrPipe = Pipe()
        process.standardError = stdErrPipe

        let handleData: @Sendable (FileHandle, OutputStream) -> Void = { [weak self] handle, stream in
            guard let self else { return }
            let data = handle.availableData
            guard data.isEmpty == false else { return }

            let string = String(decoding: data, as: UTF8.self)
            self.continuation.withLock {
                self.append(data, to: stream)
                self.outputHandler(string, self.progress)
                _ = $0?.yield(self.progress)
            }
        }

        stdOutPipe.fileHandleForReading.readabilityHandler = { handleData($0, .stdout) }
        stdErrPipe.fileHandleForReading.readabilityHandler = { handleData($0, .stderr) }

        process.terminationHandler = { [weak self] process in
            self?.finish(process: process)
        }

        do {
            try process.run()
        } catch {
            finish(throwing: error)
        }
    }

    func cancel() {
        if process.isRunning {
            process.terminate()
        }
        clearHandlers()
        continuation.withLock {
            $0 = nil
        }
    }

    private func finish(process: Process) {
        clearHandlers()
        consumeRemainingOutput()

        guard process.terminationReason == .exit, process.terminationStatus == 0 else {
            let output = output()
            finish(throwing: failureHandler(process, output.stdout, output.stderr))
            return
        }

        if let error = successHandler() {
            finish(throwing: error)
            return
        }

        takeContinuation()?.finish()
    }

    private func finish(throwing error: Error) {
        clearHandlers()
        takeContinuation()?.finish(throwing: error)
    }

    private func takeContinuation() -> AsyncThrowingStream<Progress, Error>.Continuation? {
        continuation.withLock {
            let continuation = $0
            $0 = nil
            return continuation
        }
    }

    private func clearHandlers() {
        (process.standardOutput as? Pipe)?.fileHandleForReading.readabilityHandler = nil
        (process.standardError as? Pipe)?.fileHandleForReading.readabilityHandler = nil
    }

    private func consumeRemainingOutput() {
        consumeRemainingOutput(from: process.standardOutput as? Pipe, stream: .stdout)
        consumeRemainingOutput(from: process.standardError as? Pipe, stream: .stderr)
    }

    private func consumeRemainingOutput(from pipe: Pipe?, stream: OutputStream) {
        guard let pipe else { return }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard data.isEmpty == false else { return }

        let string = String(decoding: data, as: UTF8.self)
        continuation.withLock {
            append(data, to: stream)
            outputHandler(string, progress)
            _ = $0?.yield(progress)
        }
    }

    private let capturedOutput = OSAllocatedUnfairLock<OutputStorage>(initialState: OutputStorage())

    private func append(_ data: Data, to stream: OutputStream) {
        capturedOutput.withLock {
            switch stream {
            case .stdout:
                $0.stdout.append(data)
            case .stderr:
                $0.stderr.append(data)
            }
        }
    }

    private func output() -> (stdout: String, stderr: String) {
        capturedOutput.withLock {
            (
                String(data: $0.stdout, encoding: .utf8) ?? "",
                String(data: $0.stderr, encoding: .utf8) ?? ""
            )
        }
    }

    private enum OutputStream {
        case stdout
        case stderr
    }

    private struct OutputStorage: Sendable {
        var stdout = Data()
        var stderr = Data()
    }
}
