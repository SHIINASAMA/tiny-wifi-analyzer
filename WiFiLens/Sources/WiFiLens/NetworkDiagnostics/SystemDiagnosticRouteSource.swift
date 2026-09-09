import Darwin
import Foundation

enum DiagnosticRouteParser {
    private static let requiredFields = ["destination", "gateway", "interface", "flags"]
    private static let unsupportedInterfacePrefixes = [
        "lo", "utun", "ipsec", "ppp", "tun", "tap", "bridge", "gif", "stf"
    ]

    static func parse(
        output: String,
        interfaceIndices: [String: UInt32]
    ) -> DiagnosticRouteSelection {
        var fields: [String: String] = [:]

        for line in output.split(whereSeparator: \.isNewline) {
            guard let separator = line.firstIndex(of: ":") else { continue }
            let key = line[..<separator].trimmingCharacters(in: .whitespacesAndNewlines)
            guard requiredFields.contains(key) else { continue }
            let value = line[line.index(after: separator)...]
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard fields[key] == nil else { return .ambiguous }
            fields[key] = value
        }

        guard let destination = fields["destination"], destination == "default",
              let gateway = fields["gateway"], !gateway.isEmpty,
              let interfaceName = fields["interface"], !interfaceName.isEmpty,
              let flags = fields["flags"], !flags.isEmpty else {
            return .unavailable
        }

        guard hasRequiredFlags(flags) else { return .unavailable }
        if isLinkLayerAddress(gateway) {
            return .unsupported
        }
        guard isUnicastIPv4(gateway) else { return .unavailable }
        guard let interfaceIndex = interfaceIndices[interfaceName], interfaceIndex != 0 else {
            return .unavailable
        }
        if unsupportedInterfacePrefixes.contains(where: { interfaceName.hasPrefix($0) }) {
            return .unsupported
        }

        return .selected(.init(
            interfaceName: interfaceName,
            interfaceIndex: interfaceIndex,
            address: gateway
        ))
    }

    private static func hasRequiredFlags(_ flags: String) -> Bool {
        let normalized = flags
            .trimmingCharacters(in: CharacterSet(charactersIn: "<>"))
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        let flagSet = Set(normalized)
        return flagSet.contains("UP") && flagSet.contains("GATEWAY")
    }

    private static func isLinkLayerAddress(_ address: String) -> Bool {
        address.lowercased().hasPrefix("link#") || address.contains("#")
    }

    private static func isUnicastIPv4(_ address: String) -> Bool {
        var value = in_addr()
        let result = address.withCString { pointer in
            inet_pton(AF_INET, pointer, &value)
        }
        guard result == 1 else { return false }

        let bytes = withUnsafeBytes(of: value.s_addr) { Array($0) }
        guard bytes.count == 4 else { return false }
        let first = bytes[0]
        let isUnspecified = bytes.allSatisfy { $0 == 0 }
        let isLoopback = first == 127
        let isMulticast = (224...239).contains(first)
        let isBroadcast = bytes.allSatisfy { $0 == 255 }
        return !isUnspecified && !isLoopback && !isMulticast && !isBroadcast
    }
}

struct SystemDiagnosticRouteSource: DiagnosticRouteSourcing {
    private static let executablePath = "/sbin/route"
    private static let arguments = ["-n", "get", "-inet", "default"]
    private static let outputLimit = 16 * 1024

    func currentRoute(timeout: Duration) async -> DiagnosticRouteSelection {
        let interfaceIndices = await interfaceIndices()
        let execution = DiagnosticRouteProcessExecution(
            executablePath: Self.executablePath,
            arguments: Self.arguments,
            environment: ["LC_ALL": "C"],
            outputLimit: Self.outputLimit
        )
        let result = await withTaskCancellationHandler {
            await execution.run(timeout: timeout)
        } onCancel: {
            execution.cancel()
        }

        guard result.exitCode == 0, !result.timedOut, !result.cancelled else {
            return .unavailable
        }
        return DiagnosticRouteParser.parse(
            output: result.stdout,
            interfaceIndices: interfaceIndices
        )
    }

    private func interfaceIndices() async -> [String: UInt32] {
        await Task.detached(priority: .utility) {
            Dictionary(
                uniqueKeysWithValues: NetworkInfoService.fetchAll().compactMap { interface in
                    let index = if_nametoindex(interface.interfaceName)
                    guard index != 0 else { return nil }
                    return (interface.interfaceName, index)
                }
            )
        }.value
    }
}

private struct DiagnosticRouteProcessResult: Sendable {
    let exitCode: Int32?
    let stdout: String
    let stderr: String
    let timedOut: Bool
    let cancelled: Bool
}

private final class DiagnosticRouteProcessExecution: @unchecked Sendable {
    private let lock = NSLock()
    private let process: Process
    private let stdoutPipe = Pipe()
    private let stderrPipe = Pipe()
    private let outputLimit: Int
    private var continuation: CheckedContinuation<DiagnosticRouteProcessResult, Never>?
    private var didFinish = false

    init(
        executablePath: String,
        arguments: [String],
        environment: [String: String],
        outputLimit: Int
    ) {
        process = Process()
        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = arguments
        var inheritedEnvironment = ProcessInfo.processInfo.environment
        environment.forEach { inheritedEnvironment[$0.key] = $0.value }
        process.environment = inheritedEnvironment
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe
        self.outputLimit = outputLimit
    }

    func run(timeout: Duration) async -> DiagnosticRouteProcessResult {
        let timeoutTask = Task { [weak self] in
            do {
                try await Task.sleep(for: timeout)
            } catch {
                return
            }
            self?.finish(timedOut: true, cancelled: false)
        }

        let result = await withCheckedContinuation { continuation in
            lock.lock()
            if didFinish {
                lock.unlock()
                continuation.resume(returning: DiagnosticRouteProcessResult(
                    exitCode: nil,
                    stdout: "",
                    stderr: "",
                    timedOut: false,
                    cancelled: true
                ))
            } else {
                self.continuation = continuation
                lock.unlock()
                DispatchQueue.global(qos: .utility).async { [self] in
                    execute()
                }
            }
        }
        timeoutTask.cancel()
        return result
    }

    func cancel() {
        lock.lock()
        guard !didFinish else {
            lock.unlock()
            return
        }
        process.terminate()
        let continuation = self.continuation
        self.continuation = nil
        didFinish = true
        lock.unlock()

        continuation?.resume(returning: .init(
            exitCode: nil,
            stdout: "",
            stderr: "",
            timedOut: false,
            cancelled: true
        ))
    }

    private func execute() {
        do {
            try process.run()
        } catch {
            finish(timedOut: false, cancelled: false)
            return
        }

        process.waitUntilExit()
        finish(timedOut: false, cancelled: false)
    }

    private func finish(timedOut: Bool, cancelled: Bool) {
        lock.lock()
        guard !didFinish else {
            lock.unlock()
            return
        }
        didFinish = true
        let continuation = self.continuation
        self.continuation = nil
        let exitCode = process.isRunning ? nil : process.terminationStatus
        let stdout = read(pipe: stdoutPipe.fileHandleForReading)
        let stderr = read(pipe: stderrPipe.fileHandleForReading)
        lock.unlock()

        continuation?.resume(returning: .init(
            exitCode: exitCode,
            stdout: stdout,
            stderr: stderr,
            timedOut: timedOut,
            cancelled: cancelled
        ))
    }

    private func read(pipe: FileHandle) -> String {
        let data = pipe.readDataToEndOfFile()
        let limited = data.prefix(outputLimit)
        return String(data: limited, encoding: .utf8) ?? ""
    }
}
