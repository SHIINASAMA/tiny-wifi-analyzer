import Foundation
import Observation

enum NetworkDiagnosticsPagePhase: Equatable, Sendable {
    case idle
    case running
    case completed
}

enum NetworkDiagnosticExecutionPhase: Equatable, Sendable {
    case waiting
    case checking
    case completed
}

enum NetworkDiagnosticsWorkbenchLayoutMode: Equatable, Sendable {
    case compact
    case condensed
    case regular
}

enum NetworkDiagnosticsWorkbenchLayout {
    static func mode(for availableWidth: Double) -> NetworkDiagnosticsWorkbenchLayoutMode {
        if availableWidth >= 720 { return .regular }
        if availableWidth >= 520 { return .condensed }
        return .compact
    }
}

enum NetworkDiagnosticsTablePresentation {
    static let minimumRowHeight = 54.0
    static let usesAlternatingRowBackgrounds = false
}

struct NetworkDiagnosticsWorkbenchRow: Equatable, Identifiable, Sendable {
    let id: NetworkDiagnosticCheckID
    let executionPhase: NetworkDiagnosticExecutionPhase
    let result: NetworkDiagnosticResult?
}

enum NetworkDiagnosticsWorkbenchItem: Equatable, Identifiable {
    case stageHeader(NetworkDiagnosticStage)
    case additionalHeader
    case check(NetworkDiagnosticsWorkbenchRow)

    var id: String {
        switch self {
        case .stageHeader(let stage): "header.\(String(describing: stage))"
        case .additionalHeader: "header.additional"
        case .check(let row): "check.\(row.id.rawValue)"
        }
    }
}

enum NetworkDiagnosticsPresentation {
    static func workbenchRows(
        pagePhase: NetworkDiagnosticsPagePhase,
        executionPhases: [NetworkDiagnosticCheckID: NetworkDiagnosticExecutionPhase],
        results: [NetworkDiagnosticCheckID: NetworkDiagnosticResult],
        checkIDs: [NetworkDiagnosticCheckID] = NetworkDiagnosticCheckID.allCases
    ) -> [NetworkDiagnosticsWorkbenchRow] {
        guard pagePhase != .idle else { return [] }

        return checkIDs.compactMap { id in
            let executionPhase = executionPhases[id] ?? .waiting
            if pagePhase == .running, executionPhase == .waiting {
                return nil
            }
            guard pagePhase != .completed || results[id] != nil else {
                return nil
            }
            return NetworkDiagnosticsWorkbenchRow(
                id: id,
                executionPhase: executionPhase,
                result: results[id]
            )
        }
    }

    static func stage(for checkID: NetworkDiagnosticCheckID) -> NetworkDiagnosticStage? {
        switch checkID {
        case .path, .dns, .proxy: .thisMac
        case .gatewayReachability: .lan
        case .internet: .internet
        case .ipv6: nil
        }
    }

    static func workbenchItems(
        pagePhase: NetworkDiagnosticsPagePhase,
        executionPhases: [NetworkDiagnosticCheckID: NetworkDiagnosticExecutionPhase],
        results: [NetworkDiagnosticCheckID: NetworkDiagnosticResult],
        checkIDs: [NetworkDiagnosticCheckID] = NetworkDiagnosticCheckID.allCases
    ) -> [NetworkDiagnosticsWorkbenchItem] {
        let rows = workbenchRows(
            pagePhase: pagePhase,
            executionPhases: executionPhases,
            results: results,
            checkIDs: checkIDs
        )
        guard !rows.isEmpty else { return [] }

        var items: [NetworkDiagnosticsWorkbenchItem] = []
        for currentStage in NetworkDiagnosticStage.allCases {
            let stageRows = rows.filter { stage(for: $0.id) == currentStage }
            if stageRows.isEmpty { continue }
            items.append(.stageHeader(currentStage))
            items.append(contentsOf: stageRows.map { .check($0) })
        }
        let additionalRows = rows.filter { stage(for: $0.id) == nil }
        if !additionalRows.isEmpty {
            items.append(.additionalHeader)
            items.append(contentsOf: additionalRows.map { .check($0) })
        }
        return items
    }

}

@MainActor
@Observable
final class NetworkDiagnosticsViewModel {
    static let defaultMinimumStepDuration = Duration.milliseconds(800)
    static let defaultSessionBudget = Duration.seconds(30)

    private(set) var phase = NetworkDiagnosticsPagePhase.idle
    private(set) var executionPhases: [NetworkDiagnosticCheckID: NetworkDiagnosticExecutionPhase]
    private(set) var results: [NetworkDiagnosticCheckID: NetworkDiagnosticResult] = [:]
    private(set) var logStore = NetworkDiagnosticsLogStore()
    private(set) var conclusion: NetworkDiagnosticConclusion?
    private(set) var automaticRestartCount = 0
    let checkIDs: [NetworkDiagnosticCheckID]

    var logText: String { logStore.text }

    @ObservationIgnored private let checks: [any DiagnosticCheck]
    @ObservationIgnored private let minimumStepDuration: Duration
    @ObservationIgnored private let fingerprintMonitor: any NetworkFingerprintMonitoring
    @ObservationIgnored private let guidance: GuidanceCoordinator
    @ObservationIgnored private var activeTask: Task<Void, Never>?

    init(checks: [any DiagnosticCheck] = [
        NetworkConnectivityCheck(),
        GatewayReachabilityCheck(),
        DNSResolutionCheck(),
        HTTPSControlEndpointCheck(),
        IPv6ControlEndpointCheck(),
        SystemProxyCheck(),
    ],
    minimumStepDuration: Duration = NetworkDiagnosticsViewModel.defaultMinimumStepDuration,
    fingerprintMonitor: any NetworkFingerprintMonitoring = SystemNetworkFingerprintMonitor(),
    guidance: GuidanceCoordinator = .shared
    ) {
        self.checks = checks
        self.minimumStepDuration = minimumStepDuration
        self.fingerprintMonitor = fingerprintMonitor
        self.guidance = guidance
        self.checkIDs = checks.map(\.id)
        self.executionPhases = Dictionary(
            uniqueKeysWithValues: checks.map { ($0.id, .waiting) }
        )
    }

    deinit {
        activeTask?.cancel()
    }

    @discardableResult
    func start() -> Bool {
        guard activeTask == nil else { return false }

        results = [:]
        logStore.reset()
        logStore.append("Checking…")
        conclusion = nil
        automaticRestartCount = 0
        phase = .running
        prepareExecutionPhases(retaining: [])

        activeTask = Task { [weak self] in
            await self?.runSession()
        }
        return true
    }

    func waitForCompletion() async {
        let task = activeTask
        await task?.value
    }

    func cancel() {
        activeTask?.cancel()
    }

    func clearLogs() {
        logStore.reset()
    }

    private func accept(_ result: NetworkDiagnosticResult) {
        results[result.id] = result
        executionPhases[result.id] = .completed
        logStore.append("\(result.id.logTitle): \(result.status.logTitle)")

        guard let index = checkIDs.firstIndex(of: result.id) else { return }
        let nextIndex = checkIDs.index(after: index)
        if nextIndex < checkIDs.endIndex {
            executionPhases[checkIDs[nextIndex]] = .checking
        }
    }

    private func runSession() async {
        let restartController = NetworkDiagnosticRestartController()

        await withTaskCancellationHandler {
            let fingerprintObservation = await fingerprintMonitor.observation()
            guard !Task.isCancelled else {
                phase = .idle
                return
            }
            await executeSession(
                fingerprintObservation: fingerprintObservation,
                restartController: restartController
            )
        } onCancel: {
            Task { await restartController.cancelCurrentRun() }
        }
        activeTask = nil
    }

    private func executeSession(
        fingerprintObservation: NetworkFingerprintObservation?,
        restartController: NetworkDiagnosticRestartController
    ) async {
        let monitorTask: Task<Void, Never>? = fingerprintObservation.map { observation in
            return Task {
                for await fingerprint in observation.changes {
                    guard !Task.isCancelled else { break }
                    await restartController.observe(fingerprint)
                }
            }
        }
        defer { monitorTask?.cancel() }

        var retainedResults: [NetworkDiagnosticResult] = []
        while !Task.isCancelled {
            let runner = DiagnosticRunner(
                checks: checks,
                minimumStepDuration: minimumStepDuration,
                sessionBudget: Self.defaultSessionBudget
            )
            let retainedSnapshot = retainedResults
            let runTask = Task { [weak self] in
                await runner.run(retaining: retainedSnapshot) { [weak self] result in
                    await self?.accept(result)
                }
            }
            await restartController.install(runTask)
            let orderedResults = await runTask.value

            if await restartController.completeRun() {
                automaticRestartCount += 1
                retainedResults = configurationOnlyResults(from: orderedResults)
                results = Dictionary(uniqueKeysWithValues: retainedResults.map { ($0.id, $0) })
                conclusion = nil
                prepareExecutionPhases(retaining: retainedResults)
                continue
            }

            finish(orderedResults)
            return
        }
        phase = .idle
    }

    private func configurationOnlyResults(
        from orderedResults: [NetworkDiagnosticResult]
    ) -> [NetworkDiagnosticResult] {
        let configurationOnlyIDs = Set(
            checks.filter { $0.rerunPolicy == .configurationOnly }.map(\.id)
        )
        return orderedResults.filter { configurationOnlyIDs.contains($0.id) }
    }

    private func prepareExecutionPhases(retaining retainedResults: [NetworkDiagnosticResult]) {
        let retainedIDs = Set(retainedResults.map(\.id))
        executionPhases = Dictionary(uniqueKeysWithValues: checkIDs.map { id in
            (id, retainedIDs.contains(id) ? .completed : .waiting)
        })
        if let firstPendingID = checkIDs.first(where: { !retainedIDs.contains($0) }) {
            executionPhases[firstPendingID] = .checking
        }
    }

    private func finish(_ orderedResults: [NetworkDiagnosticResult]) {
        guard !Task.isCancelled, let conclusion = NetworkDiagnosticConclusion.evaluate(
            orderedResults,
            requiredIDs: Set(checkIDs)
        ) else {
            phase = .idle
            return
        }
        self.conclusion = conclusion
        phase = .completed
        guidance.record(.diagnosticsCompleted)
    }
}

actor NetworkDiagnosticRestartController {
    private var currentRun: Task<[NetworkDiagnosticResult], Never>?
    private var restartRequested = false
    private var restartInstallPending = false
    private var cancellationRequested = false
    private var finalized = false

    func install(_ task: Task<[NetworkDiagnosticResult], Never>) {
        currentRun = task
        restartInstallPending = false
        if restartRequested || cancellationRequested {
            task.cancel()
        }
    }

    @discardableResult
    func observe(_: NetworkFingerprint) -> Bool {
        guard !finalized, !cancellationRequested else { return false }
        guard !restartInstallPending else { return true }
        restartRequested = true
        currentRun?.cancel()
        return true
    }

    func completeRun() -> Bool {
        currentRun = nil
        if cancellationRequested {
            finalized = true
            return false
        }
        if restartRequested {
            restartRequested = false
            restartInstallPending = true
            return true
        }
        finalized = true
        return false
    }

    func cancelCurrentRun() {
        cancellationRequested = true
        restartRequested = false
        restartInstallPending = false
        currentRun?.cancel()
        currentRun = nil
    }
}

#if DEBUG
extension NetworkDiagnosticsViewModel {
    /// Debug-only: publishes a synthetic completed result so the real
    /// diagnostics host renders its production conclusion strip and the
    /// production invitation card, without running a real diagnostic. Never
    /// writes Timeline, diagnostic history, or user data; the production
    /// `record(.diagnosticsCompleted)` path is not invoked (Debug triggers
    /// schedule invitations explicitly).
    func debugStageCompletedResult() {
        activeTask?.cancel()
        activeTask = nil
        let staged = checkIDs.map { id in
            NetworkDiagnosticResult(id: id, status: .normal, summary: "Debug staged result")
        }
        results = Dictionary(uniqueKeysWithValues: staged.map { ($0.id, $0) })
        executionPhases = Dictionary(uniqueKeysWithValues: staged.map { ($0.id, .completed) })
        conclusion = NetworkDiagnosticConclusion.evaluate(
            staged,
            requiredIDs: Set(checkIDs)
        )
        phase = .completed
    }
}
#endif
