import CFNetwork
import Foundation
import Network
import Testing
@testable import WiFi_Lens

@Suite("Network diagnostics models and runner")
struct NetworkDiagnosticsTests {
    @Test("all app configurations use the same local-network privacy copy")
    func localNetworkUsageDescriptionIsUnifiedAcrossAppConfigurations() throws {
        let descriptions = try appLocalNetworkUsageDescriptions()
        let expectedDescription = "WiFi Lens uses local networking when you enable its MCP server and when Network Self-Check tests reachability of your configured network proxy. These checks do not collect or transmit your Wi-Fi scan data."

        #expect(descriptions.count == 4)
        #expect(Set(descriptions.map(\.baseConfiguration)) == ["OSS.xcconfig", "PRO.xcconfig"])
        #expect(descriptions.filter { $0.baseConfiguration == "OSS.xcconfig" }.count == 2)
        #expect(descriptions.filter { $0.baseConfiguration == "PRO.xcconfig" }.count == 2)
        #expect(Set(descriptions.map(\.value)) == [expectedDescription])
        #expect(descriptions.allSatisfy { $0.value.contains("MCP server") })
        #expect(descriptions.allSatisfy { $0.value.contains("Network Self-Check") })
    }

    @Test("privacy copy selection excludes decoy non-app configurations")
    func localNetworkUsageDescriptionSelectionExcludesDecoyConfiguration() throws {
        let descriptions = try appLocalNetworkUsageDescriptions(from: privacyCopyProjectFixture)

        #expect(descriptions.count == 4)
        #expect(descriptions.allSatisfy { $0.value == "expected app copy" })
    }

    @Test("diagnostic identifiers keep path and internet distinct in execution order")
    func diagnosticIdentifierOrder() {
        #expect(NetworkDiagnosticCheckID.allCases == [.path, .gatewayReachability, .dns, .internet, .ipv6, .proxy])
        #expect(NetworkDiagnosticCheckID.path != .internet)
        #expect(Set(NetworkDiagnosticCheckID.allCases).count == 6)
    }

    @Test("route selection follows the kernel-selected interface")
    func routeSelectionUsesKernelInterface() {
        let output = """
           route to: default
        destination: default
               mask: default
            gateway: 192.0.2.1
          interface: en7
              flags: <UP,GATEWAY,DONE,STATIC,PRCLONING,GLOBAL>
        """

        let result = DiagnosticRouteParser.parse(
            output: output,
            interfaceIndices: ["en0": 4, "en7": 12]
        )

        #expect(result == .selected(.init(
            interfaceName: "en7",
            interfaceIndex: 12,
            address: "192.0.2.1"
        )))
    }

    @Test("missing selected interface does not fall back to another adapter")
    func missingInterfaceCannotSelectAnotherAdapter() {
        let output = "destination: default\ngateway: 192.0.2.1\ninterface: en7\nflags: <UP,GATEWAY>"

        #expect(DiagnosticRouteParser.parse(
            output: output,
            interfaceIndices: ["en0": 4]
        ) == .unavailable)
    }

    @Test("route parsing is independent of interface enumeration order")
    func routeSelectionIgnoresInterfaceEnumerationOrder() {
        let output = "destination: default\ngateway: 192.0.2.1\ninterface: en7\nflags: <UP,GATEWAY>"
        let firstOrder = DiagnosticRouteParser.parse(
            output: output,
            interfaceIndices: ["en0": 4, "en7": 12]
        )
        let reversedOrder = DiagnosticRouteParser.parse(
            output: output,
            interfaceIndices: ["en7": 12, "en0": 4]
        )

        #expect(firstOrder == reversedOrder)
        #expect(firstOrder == .selected(.init(
            interfaceName: "en7",
            interfaceIndex: 12,
            address: "192.0.2.1"
        )))
    }

    @Test("same gateway address remains tied to the selected interface")
    func sameGatewayAddressDoesNotCollapseInterfaceIdentity() {
        let output = "destination: default\ngateway: 192.0.2.1\ninterface: en7\nflags: <UP,GATEWAY>"

        #expect(DiagnosticRouteParser.parse(
            output: output,
            interfaceIndices: ["en0": 4, "en7": 12]
        ) == .selected(.init(
            interfaceName: "en7",
            interfaceIndex: 12,
            address: "192.0.2.1"
        )))
    }

    @Test("duplicate route fields cannot produce a selected target")
    func duplicateRouteFieldsAreRejected() {
        let output = """
        destination: default
        gateway: 192.0.2.1
        gateway: 192.0.2.254
        interface: en7
        flags: <UP,GATEWAY>
        """

        #expect(DiagnosticRouteParser.parse(
            output: output,
            interfaceIndices: ["en7": 12]
        ) == .ambiguous)
    }

    @Test("invalid gateway addresses cannot be selected")
    func invalidGatewayAddressesAreRejected() {
        let addresses = ["0.0.0.0", "224.0.0.1", "255.255.255.255", "not-an-ip"]

        for address in addresses {
            let output = "destination: default\ngateway: \(address)\ninterface: en7\nflags: <UP,GATEWAY>"
            let result = DiagnosticRouteParser.parse(
                output: output,
                interfaceIndices: ["en7": 12]
            )
            #expect(result == .unavailable)
        }
    }

    @Test("link-layer gateways and tunnel interfaces are unsupported")
    func unsupportedRouteTargetsAreRejected() {
        let linkLayer = "destination: default\ngateway: link#4\ninterface: en7\nflags: <UP,GATEWAY>"
        let tunnel = "destination: default\ngateway: 192.0.2.1\ninterface: utun3\nflags: <UP,GATEWAY>"

        #expect(DiagnosticRouteParser.parse(
            output: linkLayer,
            interfaceIndices: ["en7": 12]
        ) == .unsupported)
        #expect(DiagnosticRouteParser.parse(
            output: tunnel,
            interfaceIndices: ["utun3": 20]
        ) == .unsupported)
    }

    @Test("missing default route is unavailable")
    func missingDefaultRouteIsUnavailable() {
        let output = "gateway: 192.0.2.1\ninterface: en7\nflags: <UP,GATEWAY>"

        #expect(DiagnosticRouteParser.parse(
            output: output,
            interfaceIndices: ["en7": 12]
        ) == .unavailable)
    }

    @Test("route parser requires both UP and GATEWAY flags")
    func routeParserRequiresUsableDefaultFlags() {
        let records = [
            "destination: default\ngateway: 192.0.2.1\ninterface: en7\nflags: <GATEWAY>",
            "destination: default\ngateway: 192.0.2.1\ninterface: en7\nflags: <UP>",
            "destination: default\ngateway: 192.0.2.1\ninterface: en7\nflags: <>"
        ]

        for output in records {
            #expect(DiagnosticRouteParser.parse(
                output: output,
                interfaceIndices: ["en7": 12]
            ) == .unavailable)
        }
    }

    @Test("route command timeout terminates the child without waiting for EOF")
    func routeCommandTimeoutDoesNotWaitForChild() async {
        let execution = DiagnosticRouteProcessExecution(
            executablePath: "/bin/sleep",
            arguments: ["2"],
            environment: [:],
            outputLimit: 1024
        )
        let startedAt = ContinuousClock.now
        let result = await execution.run(timeout: .milliseconds(50))
        let elapsed = startedAt.duration(to: ContinuousClock.now)

        #expect(result.timedOut)
        #expect(elapsed < .seconds(1))
    }

    @Test("diagnostic gateway ping binds the selected interface")
    func diagnosticGatewayPingBindsSelectedInterface() async {
        let runner = RecordingGatewayPingProcessRunner(latency: 2.5)
        let pinger = GatewayPinger(processRunner: runner)
        let target = DiagnosticGatewayTarget(
            interfaceName: "en7",
            interfaceIndex: 12,
            address: "192.0.2.1"
        )

        _ = await pinger.ping(target: target)

        #expect(await runner.executablePath == "/sbin/ping")
        #expect(await runner.arguments == [
            "-b", "en7", "-c", "1", "-W", "1000", "192.0.2.1"
        ])
    }

    @Test("contextual path and gateway checks use one selected interface")
    func contextualChecksShareSelectedRouteTarget() async {
        let context = makeDiagnosticContext(
            pathState: .satisfied,
            route: .selected(.init(
                interfaceName: "en7",
                interfaceIndex: 12,
                address: "192.0.2.1"
            )),
            interfaces: [
                makeNetworkInterface(name: "en0", router: "192.0.2.1"),
                makeNetworkInterface(name: "en7", router: "192.0.2.1"),
            ]
        )
        let gateway = RecordingDiagnosticGatewayMeasurer()

        let pathResult = await NetworkConnectivityCheck(context: context).run()
        let gatewayResult = await GatewayReachabilityCheck(
            context: context,
            gatewayMeasuring: gateway,
            routeSource: nil
        ).run()

        #expect(pathResult.evidence.contains(.init(code: "path.interface", value: "en7")))
        #expect(pathResult.evidence.contains(.init(code: "path.gateway", value: "192.0.2.1")))
        #expect(gatewayResult.evidence.contains(.init(code: "gateway.interface", value: "en7")))
        #expect(await gateway.targets == [
            .init(interfaceName: "en7", interfaceIndex: 12, address: "192.0.2.1")
        ])
    }

    @Test("context capture accepts a stable route")
    func diagnosticContextCaptureAcceptsStableRoute() async {
        let route = DiagnosticRouteSelection.selected(.init(
            interfaceName: "en7",
            interfaceIndex: 12,
            address: "192.0.2.1"
        ))
        let routeSource = SequencedDiagnosticRouteSource(values: [route, route])
        let source = SystemDiagnosticNetworkContextSource(
            routeSource: routeSource,
            pathSource: StubPathSource(.satisfied),
            interfaceSource: StubNetworkInterfaceSnapshotSource(interfaces: [])
        )

        let context = await source.capture(runID: UUID(), timeout: .seconds(1))

        #expect(context?.route == route)
        #expect(context?.pathState == .satisfied)
        #expect(await routeSource.invocationCount == 2)
    }

    @Test("context capture does not publish a conflicting route")
    func diagnosticContextCaptureRejectsChangingRoute() async {
        let first = DiagnosticRouteSelection.selected(.init(
            interfaceName: "en0",
            interfaceIndex: 4,
            address: "192.0.2.1"
        ))
        let second = DiagnosticRouteSelection.selected(.init(
            interfaceName: "en7",
            interfaceIndex: 12,
            address: "192.0.2.1"
        ))
        let routeSource = SequencedDiagnosticRouteSource(values: [first, second, first, second])
        let source = SystemDiagnosticNetworkContextSource(
            routeSource: routeSource,
            pathSource: StubPathSource(.satisfied),
            interfaceSource: StubNetworkInterfaceSnapshotSource(interfaces: [])
        )

        let context = await source.capture(runID: UUID(), timeout: .seconds(1))

        #expect(context?.route == .ambiguous)
        #expect(await routeSource.invocationCount == 4)
    }

    @Test("route change during gateway ping suppresses the old result")
    func gatewayRouteChangeSuppressesStaleResult() async {
        let target = DiagnosticGatewayTarget(
            interfaceName: "en0",
            interfaceIndex: 4,
            address: "192.0.2.1"
        )
        let context = makeDiagnosticContext(
            pathState: .satisfied,
            route: .selected(target)
        )
        let gateway = RecordingDiagnosticGatewayMeasurer()
        let routeSource = SequencedDiagnosticRouteSource(values: [.unavailable])

        let result = await GatewayReachabilityCheck(
            context: context,
            gatewayMeasuring: gateway,
            routeSource: routeSource
        ).run()

        #expect(result.status == .indeterminate)
        #expect(result.evidence.contains(.init(code: "gateway.route-changed", value: nil)))
    }

    @Test("missing diagnostic route never starts a gateway ping")
    func missingDiagnosticRouteDoesNotPing() async {
        let context = makeDiagnosticContext(pathState: .satisfied, route: .unavailable)
        let gateway = RecordingDiagnosticGatewayMeasurer()

        let result = await GatewayReachabilityCheck(
            context: context,
            gatewayMeasuring: gateway
        ).run()

        #expect(result.status == .indeterminate)
        #expect(await gateway.targets.isEmpty)
    }

    @Test("blocked and skipped statuses have distinct presentations")
    func blockedAndSkippedPresentation() {
        #expect(NetworkDiagnosticStatus.blocked.presentation == .init(
            labelKey: "network_diagnostics.status.blocked",
            icon: "lock.fill",
            tone: .informational
        ))
        #expect(NetworkDiagnosticStatus.skipped.presentation == .init(
            labelKey: "network_diagnostics.status.skipped",
            icon: "forward.fill",
            tone: .muted
        ))
        #expect(NetworkDiagnosticStatus.blocked.presentation != NetworkDiagnosticStatus.indeterminate.presentation)
        #expect(NetworkDiagnosticStatus.skipped.presentation != NetworkDiagnosticStatus.indeterminate.presentation)
    }

    @Test("proxy authentication evidence maps to a credential remediation")
    func proxyAuthenticationRemediation() {
        let result = NetworkDiagnosticResult(
            id: .proxy,
            status: .abnormal,
            summary: "Proxy authentication required",
            evidence: [.init(code: "proxy.authentication-required", value: "407")]
        )

        let remediation = NetworkDiagnosticRemediation.forResult(result)

        #expect(remediation.actionKey == "network_diagnostics.remediation.proxy_authentication.action")
        #expect(remediation.rerunKey == "network_diagnostics.remediation.rerun")
    }

    @Test("indeterminate remediation does not claim a confirmed cause")
    func indeterminateRemediationIsTentative() {
        let result = NetworkDiagnosticResult(
            id: .dns,
            status: .indeterminate,
            summary: "DNS could not be determined"
        )

        let remediation = NetworkDiagnosticRemediation.forResult(result)

        #expect(remediation.causeKey == "network_diagnostics.remediation.indeterminate.cause")
        #expect(remediation.actionKey == "network_diagnostics.remediation.indeterminate.action")
    }

    @Test("proxy remediation follows final route facts instead of failed candidates")
    func proxyRemediationUsesFinalRouteFacts() {
        let result = NetworkDiagnosticResult(
            id: .proxy,
            status: .indeterminate,
            summary: "proxy route recovered",
            evidence: [.init(code: "proxy.authentication-required", value: "407")],
            proxyFacts: .init(http: .available, https: .available)
        )

        #expect(NetworkDiagnosticRemediation.forResult(result).actionKey
            == "network_diagnostics.remediation.indeterminate.action")
    }

    @Test("a blocked probe does not become an independent network fault")
    func blockedProbeIsNotAbnormal() {
        let result = NetworkDiagnosticResult.blocked(id: .internet, summary: "DNS is unavailable")
        #expect(result.status == .blocked)
        #expect(result.detail == "DNS is unavailable")
    }

    @Test("runner blocks gateway reachability after a hard path failure")
    func runnerBlocksGatewayReachabilityAfterPathFailure() async {
        let recorder = DiagnosticTestRecorder()
        let checks: [any DiagnosticCheck] = [
            StubDiagnosticCheck(id: .path, result: NetworkDiagnosticResult(id: .path, status: .abnormal, summary: "no path"), recorder: recorder),
            StubDiagnosticCheck(id: .gatewayReachability, result: NetworkDiagnosticResult(id: .gatewayReachability, status: .normal, summary: "unused"), recorder: recorder),
            StubDiagnosticCheck(id: .dns, result: NetworkDiagnosticResult(id: .dns, status: .normal, summary: "unused"), recorder: recorder),
        ]
        let runner = DiagnosticRunner(checks: checks, minimumStepDuration: .zero)

        let results = (await runner.run { _ in }).results

        #expect(results.map(\.id) == [.path, .gatewayReachability, .dns])
        #expect(results[1].status == .blocked)
        #expect(results[1].evidence.contains(.init(code: "blocked.by", value: "path")))
    }

    @Test("gateway reachability abnormal does not block downstream checks")
    func gatewayReachabilityAbnormalDoesNotBlockDownstream() async {
        let recorder = DiagnosticTestRecorder()
        let checks: [any DiagnosticCheck] = NetworkDiagnosticCheckID.allCases.map { id in
            let status: NetworkDiagnosticStatus = id == .gatewayReachability ? .abnormal : .normal
            return StubDiagnosticCheck(id: id, result: NetworkDiagnosticResult(id: id, status: status, summary: id.rawValue), recorder: recorder)
        }
        let runner = DiagnosticRunner(checks: checks, minimumStepDuration: .zero)

        let results = (await runner.run { _ in }).results

        #expect(results.map(\.id) == NetworkDiagnosticCheckID.allCases)
        #expect(results[1].status == .abnormal)
        #expect(results[2].status == .normal)
        #expect(results[3].status == .normal)
        #expect(results[4].status == .normal)
    }

    @Test("gateway reachability abnormal drives the needs attention conclusion")
    func gatewayReachabilityDrivesNeedsAttention() {
        let results = [
            NetworkDiagnosticResult(id: .path, status: .normal, summary: ""),
            NetworkDiagnosticResult(id: .gatewayReachability, status: .abnormal, summary: ""),
            NetworkDiagnosticResult(id: .dns, status: .normal, summary: ""),
            NetworkDiagnosticResult(id: .internet, status: .normal, summary: ""),
            NetworkDiagnosticResult(id: .ipv6, status: .skipped, summary: ""),
            NetworkDiagnosticResult(id: .proxy, status: .normal, summary: ""),
        ]

        #expect(NetworkDiagnosticConclusion.evaluate(results) == .needsAttention)
        #expect(NetworkDiagnosticConclusion.primaryIssue(in: results)?.id == .gatewayReachability)
    }

    @Test("stage resolver aggregates this mac from path dns and proxy and maps lan to its check")
    func stageResolverThisMacAndLan() {
        let resolver = NetworkDiagnosticStageResolver()
        let abnormalDNS: [NetworkDiagnosticCheckID: NetworkDiagnosticResult] = [
            .path: .init(id: .path, status: .normal, summary: ""),
            .dns: .init(id: .dns, status: .abnormal, summary: ""),
            .proxy: .init(id: .proxy, status: .normal, summary: ""),
            .gatewayReachability: .init(id: .gatewayReachability, status: .normal, summary: ""),
        ]

        #expect(resolver.status(for: .thisMac, results: abnormalDNS) == .abnormal)
        #expect(resolver.status(for: .lan, results: abnormalDNS) == .normal)
        let proxyOnly: [NetworkDiagnosticCheckID: NetworkDiagnosticResult] = [
            .path: .init(id: .path, status: .normal, summary: ""),
            .dns: .init(id: .dns, status: .normal, summary: ""),
            .proxy: .init(id: .proxy, status: .abnormal, summary: ""),
            .gatewayReachability: .init(id: .gatewayReachability, status: .normal, summary: ""),
        ]
        #expect(resolver.status(for: .thisMac, results: proxyOnly) == .abnormal)
        #expect(resolver.status(for: .thisMac, results: [:]) == nil)
        let missingContributors: [NetworkDiagnosticCheckID: NetworkDiagnosticResult] = [
            .path: .init(id: .path, status: .normal, summary: ""),
        ]
        #expect(resolver.status(for: .thisMac, results: missingContributors) == nil)
    }

    @Test("internet stage follows the internet check and ignores dns and ipv6")
    func stageResolverInternet() {
        let resolver = NetworkDiagnosticStageResolver()

        #expect(resolver.status(for: .internet, results: [.internet: .init(id: .internet, status: .normal, summary: "")]) == .normal)
        #expect(resolver.status(for: .internet, results: [.internet: .init(id: .internet, status: .abnormal, summary: "")]) == .abnormal)
        #expect(resolver.status(for: .internet, results: [.internet: .init(id: .internet, status: .indeterminate, summary: "")]) == .indeterminate)
        #expect(resolver.status(for: .internet, results: [.internet: .init(id: .internet, status: .blocked, summary: "")]) == .blocked)
        let extras: [NetworkDiagnosticCheckID: NetworkDiagnosticResult] = [
            .internet: .init(id: .internet, status: .normal, summary: ""),
            .dns: .init(id: .dns, status: .abnormal, summary: ""),
            .ipv6: .init(id: .ipv6, status: .abnormal, summary: ""),
        ]
        #expect(resolver.status(for: .internet, results: extras) == .normal)
    }

    @Test("internet stage requires the internet result")
    func stageResolverRequiresInternetResult() {
        let resolver = NetworkDiagnosticStageResolver()
        let partial: [NetworkDiagnosticCheckID: NetworkDiagnosticResult] = [
            .dns: .init(id: .dns, status: .normal, summary: ""),
        ]

        #expect(resolver.status(for: .internet, results: partial) == nil)
    }

    @Test("pipeline presentation maps stages to stations and edges")
    func pipelinePresentation() {
        let results: [NetworkDiagnosticCheckID: NetworkDiagnosticResult] = [
            .path: .init(id: .path, status: .normal, summary: ""),
            .gatewayReachability: .init(id: .gatewayReachability, status: .abnormal, summary: ""),
            .dns: .init(id: .dns, status: .normal, summary: ""),
            .internet: .init(id: .internet, status: .normal, summary: ""),
            .ipv6: .init(id: .ipv6, status: .skipped, summary: ""),
            .proxy: .init(id: .proxy, status: .normal, summary: ""),
        ]
        let presentation = NetworkDiagnosticsPipelinePresentation.from(
            results: results,
            executionPhases: [:]
        )

        #expect(presentation.stations.map(\.kind) == [.thisMac, .router, .internet])
        #expect(presentation.edges.map(\.kind) == [.lan, .internet])
        #expect(presentation.stations[0].status == .normal)
        #expect(presentation.stations[1].status == .abnormal)
        #expect(presentation.stations[1].isUnreachable)
        #expect(presentation.stations[2].status == .normal)
        #expect(!presentation.stations[2].isUnreachable)
        #expect(presentation.edges[0].status == .abnormal)
        #expect(presentation.edges[1].status == .normal)
    }

    @Test("pipeline edge becomes active while its checks are running")
    func pipelineEdgeActive() {
        let executionPhases: [NetworkDiagnosticCheckID: NetworkDiagnosticExecutionPhase] = [
            .gatewayReachability: .checking,
        ]
        let presentation = NetworkDiagnosticsPipelinePresentation.from(
            results: [:],
            executionPhases: executionPhases
        )

        #expect(presentation.edges[0].isActive)
        #expect(!presentation.edges[1].isActive)
    }

    @Test("runner executes checks and publishes results in order")
    func runnerOrder() async {
        let invocations = DiagnosticTestRecorder()
        let publications = DiagnosticTestRecorder()
        let checks: [any DiagnosticCheck] = NetworkDiagnosticCheckID.allCases.map { id in
            StubDiagnosticCheck(
                id: id,
                result: NetworkDiagnosticResult(id: id, status: .normal, summary: id.rawValue),
                recorder: invocations
            )
        }

        let results = (await DiagnosticRunner(checks: checks).run { result in
            await publications.record(result.id)
        }).results

        #expect(results.map(\.id) == NetworkDiagnosticCheckID.allCases)
        #expect(await invocations.values == NetworkDiagnosticCheckID.allCases)
        #expect(await publications.values == NetworkDiagnosticCheckID.allCases)
    }

    @Test("runner enforces an overall session budget")
    func runnerEnforcesOverallBudget() async {
        let probe = BudgetAwareDiagnosticProbe()
        let outcome = await DiagnosticRunner(
            checks: [BudgetAwareDiagnosticCheck(probe: probe)],
            sessionBudget: .milliseconds(50)
        ).run { _ in }

        #expect(await probe.wasCancelled)
        #expect(outcome.results.map(\.id) == [.path])
        #expect(outcome.results.first?.status == .indeterminate)
        #expect(outcome.results.first?.evidence == [.init(code: "check.timeout", value: nil)])
        #expect(outcome.pendingIDs.isEmpty)
        #expect(outcome.endReason == .timedOut)
    }

    @Test("runner returns when a cancelled check ignores cancellation")
    func runnerDoesNotWaitForCancellationIgnoringCheck() async {
        let probe = CancellationIgnoringDiagnosticProbe()
        let task = Task {
            await DiagnosticRunner(
                checks: [CancellationIgnoringProbeDiagnosticCheck(probe: probe)],
                sessionBudget: .seconds(30)
            ).run { _ in }
        }

        await probe.waitForInvocationCount(1)
        task.cancel()
        let outcome = await task.value

        #expect(outcome.results.isEmpty)
        #expect(outcome.pendingIDs == [.path])
        #expect(outcome.endReason == .cancelled)
        await probe.release(invocation: 1)
    }

    @Test("publication gate rejects an old run after a replacement starts")
    func oldRunCannotPublishIntoNewRun() {
        let oldID = UUID()
        let newID = UUID()
        let gate = DiagnosticPublicationGate(activeRunID: newID)

        #expect(!gate.accepts(oldID))
        #expect(gate.accepts(newID))
    }

    @Test("runner preserves completed results and identifies pending checks on cancellation")
    func runnerReturnsPartialCancelledOutcome() async {
        let probe = BlockingDiagnosticProbe()
        let checks: [any DiagnosticCheck] = [
            StubDiagnosticCheck(
                id: .path,
                result: .init(id: .path, status: .normal, summary: "path"),
                recorder: DiagnosticTestRecorder()
            ),
            BlockingProbeDiagnosticCheck(id: .gatewayReachability, probe: probe),
        ]
        let runner = DiagnosticRunner(checks: checks, minimumStepDuration: .zero)
        let task = Task { await runner.run { _ in } }

        await probe.waitForInvocationCount(1)
        task.cancel()
        let outcome = await task.value

        #expect(outcome.results.map(\.id) == [.path])
        #expect(outcome.pendingIDs == [.gatewayReachability])
        #expect(outcome.endReason == .cancelled)
    }

    @Test("indeterminate DNS does not block internet or IPv6")
    func indeterminateDNSDoesNotBlockInternetOrIPv6() async {
        let invocations = DiagnosticTestRecorder()
        let checks: [any DiagnosticCheck] = NetworkDiagnosticCheckID.allCases.map { id in
            StubDiagnosticCheck(
                id: id,
                result: NetworkDiagnosticResult(
                    id: id,
                    status: id == .dns ? .indeterminate : .normal,
                    summary: id.rawValue
                ),
                recorder: invocations
            )
        }

        let results = (await DiagnosticRunner(checks: checks).run { _ in }).results

        #expect(results.map(\.status) == [.normal, .normal, .indeterminate, .normal, .normal, .normal])
        #expect(await invocations.values == [.path, .gatewayReachability, .dns, .internet, .ipv6, .proxy])
    }

    @Test("abnormal DNS does not block independent hostname checks")
    func abnormalDNSDoesNotBlockHostnameDependentChecks() async {
        let invocations = DiagnosticTestRecorder()
        let checks: [any DiagnosticCheck] = NetworkDiagnosticCheckID.allCases.map { id in
            StubDiagnosticCheck(
                id: id,
                result: NetworkDiagnosticResult(
                    id: id,
                    status: id == .dns ? .abnormal : .normal,
                    summary: id.rawValue
                ),
                recorder: invocations
            )
        }

        let results = (await DiagnosticRunner(checks: checks).run { _ in }).results

        #expect(results.map(\.status) == [.normal, .normal, .abnormal, .normal, .normal, .normal])
        #expect(await invocations.values == [.path, .gatewayReachability, .dns, .internet, .ipv6, .proxy])
    }

    @Test("indeterminate path continues independent evidence probes")
    func indeterminatePathContinuesIndependentEvidenceProbes() async {
        let invocations = DiagnosticTestRecorder()
        let checks: [any DiagnosticCheck] = NetworkDiagnosticCheckID.allCases.map { id in
            StubDiagnosticCheck(
                id: id,
                result: NetworkDiagnosticResult(
                    id: id,
                    status: id == .path ? .indeterminate : .normal,
                    summary: id.rawValue
                ),
                recorder: invocations
            )
        }

        let results = (await DiagnosticRunner(checks: checks).run { _ in }).results

        #expect(results.map(\.status) == [.indeterminate, .normal, .normal, .normal, .normal, .normal])
        #expect(await invocations.values == [.path, .gatewayReachability, .dns, .internet, .ipv6, .proxy])
    }

    @Test("abnormal path blocks network probes")
    func abnormalPathBlocksNetworkProbes() async {
        let invocations = DiagnosticTestRecorder()
        let checks: [any DiagnosticCheck] = NetworkDiagnosticCheckID.allCases.map { id in
            StubDiagnosticCheck(
                id: id,
                result: NetworkDiagnosticResult(
                    id: id,
                    status: id == .path ? .abnormal : .normal,
                    summary: id.rawValue
                ),
                recorder: invocations
            )
        }

        let results = (await DiagnosticRunner(checks: checks).run { _ in }).results

        #expect(results.map(\.status) == [.abnormal, .blocked, .blocked, .blocked, .blocked, .blocked])
        #expect(await invocations.values == [.path])
    }

    @Test("runner does not delay the next operation for presentation")
    func runnerMinimumPresentationDuration() async {
        let check = StubDiagnosticCheck(
            id: .path,
            result: NetworkDiagnosticResult(id: .path, status: .normal, summary: "ok"),
            recorder: DiagnosticTestRecorder()
        )
        let outcome = await DiagnosticRunner(
            checks: [check],
            minimumStepDuration: .milliseconds(50)
        ).run { _ in }

        #expect(outcome.endReason == .completed)
    }

    @Test("production diagnostics present each check for at least 0.8 seconds")
    @MainActor
    func productionMinimumPresentationDuration() {
        #expect(NetworkDiagnosticsViewModel.defaultMinimumStepDuration == .milliseconds(800))
    }

    @Test("system path failure makes the network unavailable")
    func unavailableConclusion() {
        let results = makeResults(path: .abnormal, dns: .normal, internet: .normal, proxy: .normal)
        #expect(NetworkDiagnosticConclusion.evaluate(results) == .networkUnavailable)
    }

    @Test("DNS or proxy failure needs attention")
    func abnormalConclusion() {
        #expect(NetworkDiagnosticConclusion.evaluate(
            makeResults(path: .normal, dns: .abnormal, internet: .normal, proxy: .normal)
        ) == .needsAttention)
        #expect(NetworkDiagnosticConclusion.evaluate(
            makeResults(path: .normal, dns: .normal, internet: .normal, proxy: .abnormal)
        ) == .needsAttention)
    }

    @Test("failed base HTTPS suppresses proxy endpoint symptom without declaring outage")
    func conclusionSuppressesProxySymptom() {
        var results = makeResults(
            path: .normal,
            dns: .indeterminate,
            internet: .abnormal,
            proxy: .abnormal
        )
        results[3] = NetworkDiagnosticResult(
            id: .internet,
            status: .abnormal,
            summary: "internet",
            evidence: [.init(
                code: "https.connectivity-error",
                value: String(URLError.timedOut.rawValue)
            )]
        )

        #expect(NetworkDiagnosticConclusion.evaluate(results) == .needsAttention)
    }

    @Test("failed direct path with a usable HTTPS proxy needs attention")
    func usableProxyPreventsNetworkUnavailableConclusion() {
        var results = makeResults(
            path: .normal,
            dns: .normal,
            internet: .abnormal,
            proxy: .normal
        )
        results[5] = NetworkDiagnosticResult(
            id: .proxy,
            status: .normal,
            summary: "proxy",
            evidence: [.init(code: "proxy.https.egress-status", value: "200")]
        )

        #expect(NetworkDiagnosticConclusion.evaluate(results) == .needsAttention)
    }

    @Test("DIRECT routing without direct egress needs attention")
    func directRouteDecisionDoesNotProveConnectivity() {
        var results = makeResults(
            path: .normal,
            dns: .normal,
            internet: .abnormal,
            proxy: .normal
        )
        results[3] = NetworkDiagnosticResult(
            id: .internet,
            status: .abnormal,
            summary: "internet",
            evidence: [.init(
                code: "https.connectivity-error",
                value: String(URLError.notConnectedToInternet.rawValue)
            )]
        )
        results[5] = NetworkDiagnosticResult(
            id: .proxy,
            status: .normal,
            summary: "proxy",
            evidence: [.init(code: "proxy.https.egress-status", value: "base-check")]
        )

        #expect(NetworkDiagnosticConclusion.evaluate(results) == .needsAttention)
    }

    @Test("base HTTPS success and explicit proxy failure needs attention")
    func proxyIsIndependentWhenBasePathWorks() {
        let results: [NetworkDiagnosticResult] = makeResults(
            path: .normal,
            dns: .normal,
            internet: .normal,
            proxy: .abnormal
        )

        #expect(NetworkDiagnosticConclusion.evaluate(results) == .needsAttention)
    }

    @Test("captive portal symptom after HTTPS success needs attention")
    func captivePortalSymptomAfterHTTPSSuccess() {
        let results = [
            NetworkDiagnosticResult(id: .path, status: .normal, summary: "path"),
            NetworkDiagnosticResult(id: .gatewayReachability, status: .normal, summary: "gateway"),
            NetworkDiagnosticResult(id: .dns, status: .normal, summary: "dns"),
            NetworkDiagnosticResult(
                id: .internet,
                status: .abnormal,
                summary: "internet",
                evidence: [
                    .init(code: "https.available", value: "200"),
                    .init(code: "captive-portal.suspected", value: nil),
                ]
            ),
            NetworkDiagnosticResult(id: .ipv6, status: .skipped, summary: "ipv6"),
            NetworkDiagnosticResult(id: .proxy, status: .normal, summary: "proxy"),
        ]

        #expect(NetworkDiagnosticConclusion.evaluate(results) == .needsAttention)
        let assessment = NetworkDiagnosticAssessmentResolver().resolve(
            results: Dictionary(uniqueKeysWithValues: results.map { ($0.id, $0) }),
            complete: true
        )
        #expect(assessment.primaryIssue?.id == .internet)
    }

    @Test("an indeterminate result needs attention")
    func indeterminateConclusion() {
        let results = makeResults(path: .normal, dns: .indeterminate, internet: .normal, proxy: .normal)
        #expect(NetworkDiagnosticConclusion.evaluate(results) == .needsAttention)
    }

    @Test("normal required results and skipped optional IPv6 make the network normal")
    func fourResultNormalConclusion() {
        let results = makeResults(path: .normal, dns: .normal, internet: .normal, proxy: .normal)
        #expect(NetworkDiagnosticConclusion.evaluate(results) == .networkNormal)
    }

    @Test("verified base connectivity keeps an unverified DIRECT proxy route neutral")
    func verifiedBaseConnectivityKeepsDirectRouteNeutral() {
        var results = makeResults(
            path: .normal,
            dns: .normal,
            internet: .normal,
            proxy: .indeterminate
        )
        results[5] = NetworkDiagnosticResult(
            id: .proxy,
            status: .indeterminate,
            summary: "direct routing selected",
            evidence: [.init(code: "proxy.https.egress-status", value: "base-check")],
            proxyFacts: .init(http: .unverified, https: .unverified)
        )

        #expect(NetworkDiagnosticConclusion.evaluate(results) == .networkNormal)
    }

    @Test("PAC resolution failures are not neutralized as explicit DIRECT")
    func pacResolutionFailureDoesNotBecomeNormal() {
        let results = makeResults(
            path: .normal,
            dns: .normal,
            internet: .normal,
            proxy: .indeterminate
        ).map { result in
            guard result.id == .proxy else { return result }
            return NetworkDiagnosticResult(
                id: .proxy,
                status: .indeterminate,
                summary: "proxy resolution failed",
                evidence: [
                    .init(code: "proxy.http.resolution", value: "pac-timeout"),
                    .init(code: "proxy.https.resolution", value: "pac-timeout"),
                ],
                proxyFacts: .init(http: .unverified, https: .unverified)
            )
        }

        let assessment = NetworkDiagnosticAssessmentResolver().resolve(
            results: Dictionary(uniqueKeysWithValues: results.map { ($0.id, $0) }),
            complete: true
        )

        #expect(assessment.conclusion == .needsAttention)
    }

    @Test("a single HTTPS target failure is needs attention, not universal outage")
    func singleHTTPSFailureIsNotNetworkUnavailable() {
        var results = makeResults(
            path: .normal,
            dns: .normal,
            internet: .abnormal,
            proxy: .indeterminate
        )
        results[3] = NetworkDiagnosticResult(
            id: .internet,
            status: .abnormal,
            summary: "one HTTPS target failed",
            evidence: [.init(code: "https.connectivity-error", value: nil)]
        )

        #expect(NetworkDiagnosticConclusion.evaluate(results) == .needsAttention)
    }

    @Test("DNS uncertainty is not hidden by a neutral DIRECT proxy")
    func dnsUncertaintyRemainsVisibleAlongsideDirectProxy() {
        var results = makeResults(
            path: .normal,
            dns: .indeterminate,
            internet: .normal,
            proxy: .indeterminate
        )
        results[5] = NetworkDiagnosticResult(
            id: .proxy,
            status: .indeterminate,
            summary: "direct routing selected",
            proxyFacts: .init(http: .unverified, https: .unverified)
        )

        let assessment = NetworkDiagnosticAssessmentResolver().resolve(
            results: Dictionary(uniqueKeysWithValues: results.map { ($0.id, $0) }),
            complete: true
        )

        #expect(assessment.conclusion == .needsAttention)
        #expect(assessment.stages.first { $0.stage == .thisMac }?.status == .indeterminate)
    }

    @Test("HTTPS availability is retained even when HTTP proxy routing fails")
    func httpsAvailabilityDoesNotDependOnHTTP() {
        let facts = DiagnosticProxyFacts(http: .unavailable, https: .available)
        #expect(facts.https == .available)

        let results: [NetworkDiagnosticResult] = makeResults(
            path: .normal,
            dns: .normal,
            internet: .abnormal,
            proxy: .abnormal
        ).map { result in
            if result.id == .internet {
                return NetworkDiagnosticResult(
                    id: result.id,
                    status: result.status,
                    summary: result.summary,
                    evidence: [.init(code: "https.connectivity-error", value: nil)]
                )
            }
            if result.id == .proxy {
                return NetworkDiagnosticResult(
                    id: result.id,
                    status: result.status,
                    summary: result.summary,
                    evidence: [.init(code: "proxy.endpoint-unavailable", value: nil)],
                    proxyFacts: facts
                )
            }
            return result
        }

        let assessment = NetworkDiagnosticAssessmentResolver().resolve(
            results: Dictionary(uniqueKeysWithValues: results.map { ($0.id, $0) }),
            complete: true
        )
        #expect(assessment.conclusion == .needsAttention)
        #expect(assessment.primaryIssue?.id == .proxy)
    }

    @Test("recovered proxy candidates do not leave an authentication action")
    func recoveredProxyCandidateDoesNotRemainActionable() {
        let results: [NetworkDiagnosticResult] = makeResults(
            path: .normal,
            dns: .normal,
            internet: .normal,
            proxy: .normal
        ).map { result in
            guard result.id == .proxy else { return result }
            return NetworkDiagnosticResult(
                id: .proxy,
                status: .normal,
                summary: "HTTPS proxy recovered",
                evidence: [.init(code: "proxy.https.authentication-required", value: "407")],
                proxyFacts: .init(http: .available, https: .available)
            )
        }

        let assessment = NetworkDiagnosticAssessmentResolver().resolve(
            results: Dictionary(uniqueKeysWithValues: results.map { ($0.id, $0) }),
            complete: true
        )
        #expect(assessment.conclusion == .networkNormal)
        #expect(assessment.primaryIssue == nil)
    }

    @Test("no global IPv6 address is skipped without changing a normal conclusion")
    func ipv6SkippedIsConclusionNeutral() async {
        let ipv6 = await IPv6ControlEndpointCheck(
            loader: StubIPv6Loader(.noGlobalAddress)
        ).run()

        #expect(ipv6.id == .ipv6)
        #expect(ipv6.status == .skipped)
        #expect(NetworkDiagnosticConclusion.evaluate(
            makeResults(
                path: .normal,
                dns: .normal,
                internet: .normal,
                ipv6: ipv6.status,
                proxy: .normal
            )
        ) == .networkNormal)
    }

    @Test("IPv6 failure does not affect the overall conclusion")
    func ipv6IsConclusionNeutral() async {
        let ipv6 = await IPv6ControlEndpointCheck(loader: StubIPv6Loader(.failed)).run()

        #expect(ipv6.status == .indeterminate)
        #expect(ipv6.evidence.contains(.init(code: "ipv6.unavailable", value: nil)))
        #expect(NetworkDiagnosticConclusion.evaluate(
            makeResults(
                path: .normal,
                dns: .normal,
                internet: .normal,
                ipv6: ipv6.status,
                proxy: .normal
            )
        ) == .networkNormal)
    }

    @Test("IPv6 control endpoint success is normal")
    func ipv6Success() async {
        let result = await IPv6ControlEndpointCheck(loader: StubIPv6Loader(.succeeded)).run()

        #expect(result.status == .normal)
        #expect(result.evidence.contains(.init(code: "ipv6.available", value: nil)))
    }

    @Test("system IPv6 loader connects only to a resolved IPv6 literal")
    func ipv6LoaderForcesResolvedAddress() async {
        let recorder = IPv6LoaderTestRecorder()
        let loader = SystemIPv6ControlEndpointLoader(
            addressSource: StubGlobalIPv6AddressSource(hasAddress: true),
            resolver: StubIPv6AddressResolver(addresses: ["2001:db8::42"]),
            connector: RecordingIPv6HTTPSConnector(succeeds: true, recorder: recorder)
        )
        let endpoint = URL(string: "https://control.example/health")!

        let outcome = await loader.load(url: endpoint, timeout: .seconds(4))

        #expect(outcome == .succeeded)
        let requests = await recorder.requests
        #expect(requests.count == 1)
        #expect(requests.first?.url == endpoint)
        #expect(requests.first?.ipv6Address == "2001:db8::42")
        #expect(requests.first?.serverName == "control.example")
        #expect(requests.first.map { $0.timeout > .zero && $0.timeout <= .seconds(4) } == true)
    }

    @Test("system IPv6 loader tries later resolved addresses")
    func ipv6LoaderFallsBackAcrossAddresses() async {
        let connector = SequencedIPv6HTTPSConnector(successfulAddress: "2001:db8::2")
        let loader = SystemIPv6ControlEndpointLoader(
            addressSource: StubGlobalIPv6AddressSource(hasAddress: true),
            resolver: StubIPv6AddressResolver(addresses: ["2001:db8::1", "2001:db8::2"]),
            connector: connector
        )

        let outcome = await loader.load(
            url: URL(string: "https://control.example/health")!,
            timeout: .seconds(4)
        )

        #expect(outcome == .succeeded)
        #expect(await connector.addresses == ["2001:db8::1", "2001:db8::2"])
        let timeouts = await connector.timeouts
        #expect(timeouts.count == 2)
        #expect(timeouts.first.map { $0 > .zero && $0 <= .seconds(2) } == true)
        #expect(timeouts.last.map { $0 > .zero && $0 <= .seconds(4) } == true)
    }

    @Test("system IPv6 loader skips resolution when no global address is present")
    func ipv6LoaderSkipsWithoutGlobalAddress() async {
        let resolver = RecordingIPv6AddressResolver(addresses: ["2001:db8::42"])
        let loader = SystemIPv6ControlEndpointLoader(
            addressSource: StubGlobalIPv6AddressSource(hasAddress: false),
            resolver: resolver,
            connector: StubIPv6HTTPSConnector(succeeds: true)
        )

        let outcome = await loader.load(
            url: URL(string: "https://control.example/")!,
            timeout: .seconds(4)
        )

        #expect(outcome == .noGlobalAddress)
        #expect(await resolver.hosts.isEmpty)
    }

    @Test("IPv6 DNS configures delivery before the resolver context owns the service")
    func ipv6DNSActivationOrder() {
        var events: [String] = []

        IPv6DNSServiceActivation.configureThenInstall(
            configureDelivery: { events.append("configure") },
            installOwnership: { events.append("install") }
        )

        #expect(events == ["configure", "install"])
    }

    @Test("an incomplete run has no conclusion")
    func incompleteConclusion() {
        let result = NetworkDiagnosticResult(id: .path, status: .normal, summary: "ok")
        #expect(NetworkDiagnosticConclusion.evaluate([result]) == nil)
    }

    @Test("workbench table adapts columns to available width")
    func adaptiveWorkbenchLayoutMode() {
        #expect(NetworkDiagnosticsWorkbenchLayout.mode(for: 519) == .compact)
        #expect(NetworkDiagnosticsWorkbenchLayout.mode(for: 520) == .condensed)
        #expect(NetworkDiagnosticsWorkbenchLayout.mode(for: 719) == .condensed)
        #expect(NetworkDiagnosticsWorkbenchLayout.mode(for: 720) == .regular)
    }

    @Test("result table uses comfortable rows without alternating empty backgrounds")
    func comfortableResultTablePresentation() {
        #expect(NetworkDiagnosticsTablePresentation.minimumRowHeight == 54)
        #expect(NetworkDiagnosticsTablePresentation.usesAlternatingRowBackgrounds == false)
    }

    @Test("workbench items interleave stage headers with check rows")
    func workbenchItemGrouping() {
        let path = NetworkDiagnosticResult(
            id: .path,
            status: .normal,
            summary: "connected"
        )
        let executionPhases: [NetworkDiagnosticCheckID: NetworkDiagnosticExecutionPhase] = [
            .path: .completed,
            .dns: .checking,
            .proxy: .waiting,
        ]

        #expect(NetworkDiagnosticsPresentation.workbenchItems(
            pagePhase: .idle,
            executionPhases: executionPhases,
            results: [:]
        ).isEmpty)

        let runningItems = NetworkDiagnosticsPresentation.workbenchItems(
            pagePhase: .running,
            executionPhases: executionPhases,
            results: [.path: path],
            checkIDs: [.path, .dns, .proxy]
        )
        #expect(runningItems.map(\.id) == ["header.thisMac", "check.path", "check.dns"])
        #expect(runningItems[0] == .stageHeader(.thisMac))
        #expect(runningItems[1] == .check(.init(id: .path, executionPhase: .completed, result: path)))

        let completedResults = Dictionary(uniqueKeysWithValues: makeResults(
            path: .normal,
            dns: .abnormal,
            internet: .normal,
            proxy: .indeterminate
        ).map { ($0.id, $0) })
        let completedItems = NetworkDiagnosticsPresentation.workbenchItems(
            pagePhase: .completed,
            executionPhases: executionPhases,
            results: completedResults,
            checkIDs: [.path, .dns, .ipv6, .proxy]
        )
        #expect(completedItems.map(\.id) == [
            "header.thisMac", "check.path", "check.dns", "check.proxy",
            "header.additional", "check.ipv6",
        ])
        #expect(completedItems[4] == .additionalHeader)

        let timedOutItems = NetworkDiagnosticsPresentation.workbenchItems(
            pagePhase: .completed,
            executionPhases: [.path: .completed, .dns: .waiting],
            results: [.path: path],
            checkIDs: [.path, .dns],
            endReason: .timedOut
        )
        #expect(timedOutItems.last == .check(.init(
            id: .dns,
            executionPhase: .waiting,
            result: nil,
            pendingReason: .timedOut
        )))
    }

    @Test("system path check maps path states")
    func pathMapping() async {
        let satisfied = await NetworkConnectivityCheck(pathSource: StubPathSource(.satisfied)).run()
        #expect(satisfied.id == .path)
        #expect(satisfied.status == .normal)
        #expect(await NetworkConnectivityCheck(pathSource: StubPathSource(.unsatisfied)).run().status == .abnormal)
        #expect(await NetworkConnectivityCheck(pathSource: StubPathSource(.requiresConnection)).run().status == .indeterminate)
        #expect(await NetworkConnectivityCheck(pathSource: StubPathSource(nil)).run().status == .indeterminate)
    }

    @Test("a satisfied system path is not an internet-success result")
    func pathCheckReportsPathOnly() async {
        let result = await NetworkConnectivityCheck(pathSource: StubPathSource(.satisfied)).run()

        #expect(result.id == .path)
        #expect(result.id != .internet)
        #expect(result.detail == String(
            localized: "network_diagnostics.path.normal.summary",
            comment: "Network self-check system path success detail"
        ))
    }

    @Test("gateway reachability check succeeds with latency evidence")
    func gatewayReachabilitySuccess() async {
        let result = await GatewayReachabilityCheck(
            interfaceSource: StubNetworkInterfaceSource(interface: makeNetworkInterface(router: "192.0.2.1")),
            gatewayLatency: StubGatewayLatencyProvider(result: GatewayLatencyResult(
                timestamp: Date(),
                routerIP: "192.0.2.1",
                latencyMs: 2.5
            ))
        ).run()

        #expect(result.id == .gatewayReachability)
        #expect(result.status == .normal)
        #expect(result.evidence.contains(.init(code: "gateway.latency-ms", value: "2.5")))
    }

    @Test("gateway nonresponse remains indeterminate")
    func gatewayNonresponseIsIndeterminate() async {
        let result = await GatewayReachabilityCheck(
            interfaceSource: StubNetworkInterfaceSource(interface: makeNetworkInterface(router: "192.0.2.1")),
            gatewayLatency: StubGatewayLatencyProvider(result: GatewayLatencyResult(
                timestamp: Date(),
                routerIP: "192.0.2.1",
                error: .gatewayPingFailed("192.0.2.1")
            ))
        ).run()

        #expect(result.status == .indeterminate)
        #expect(result.evidence.contains(.init(code: "gateway.no-response", value: "192.0.2.1")))
    }

    @Test("successful HTTPS access neutralizes gateway ICMP nonresponse")
    func gatewayNonresponseDoesNotDowngradeSuccessfulHTTPS() {
        var results = makeResults(
            path: .normal,
            gateway: .indeterminate,
            dns: .normal,
            internet: .normal,
            proxy: .normal
        )
        results[1] = NetworkDiagnosticResult(
            id: .gatewayReachability,
            status: .indeterminate,
            summary: "gateway did not answer ICMP",
            evidence: [.init(code: "gateway.no-response", value: "192.0.2.1")]
        )
        results[3] = NetworkDiagnosticResult(
            id: .internet,
            status: .normal,
            summary: "HTTPS available",
            evidence: [.init(code: "https.available", value: "200")]
        )

        let assessment = NetworkDiagnosticAssessmentResolver().resolve(
            results: Dictionary(uniqueKeysWithValues: results.map { ($0.id, $0) }),
            complete: true
        )

        #expect(assessment.conclusion == .networkNormal)
        #expect(assessment.primaryIssue == nil)
        #expect(assessment.stages.first { $0.stage == .lan }?.status == .indeterminate)
    }

    @Test("gateway reachability is indeterminate without a router IP")
    func gatewayReachabilityWithoutRouterIP() async {
        let result = await GatewayReachabilityCheck(
            interfaceSource: StubNetworkInterfaceSource(interface: makeNetworkInterface(router: nil)),
            gatewayLatency: StubGatewayLatencyProvider(result: GatewayLatencyResult(
                timestamp: Date(),
                error: .missingRouterIP
            ))
        ).run()

        #expect(result.status == .indeterminate)
        #expect(result.evidence.contains(.init(code: "gateway.unavailable", value: nil)))
    }

    @Test("path check keeps interface evidence without gateway latency")
    func pathCheckKeepsInterfaceEvidence() async {
        let result = await NetworkConnectivityCheck(
            pathSource: StubPathSource(.satisfied),
            interfaceSource: StubNetworkInterfaceSource(interface: makeNetworkInterface(router: "192.0.2.1"))
        ).run()

        #expect(result.status == .normal)
        #expect(result.evidence.contains(.init(code: "path.interface", value: "en0")))
        #expect(result.evidence.contains(.init(code: "path.local-ip", value: "192.0.2.10")))
        #expect(result.evidence.contains(.init(code: "path.router", value: "192.0.2.1")))
        #expect(!result.evidence.contains { $0.code.hasPrefix("gateway.") })
    }

    @Test("captive-portal probe rejects a rewritten response")
    func captivePortalProbeRejectsRewrittenResponse() async {
        let check = HTTPSControlEndpointCheck(
            loader: StubControlLoader(
                httpsStatus: 204,
                httpStatus: 200,
                httpBody: "login"
            )
        )

        let result = await check.run()

        #expect(result.id == .internet)
        #expect(result.evidence.contains(.init(code: "captive-portal.suspected", value: nil)))
    }

    @Test("control endpoint success verifies HTTPS and Apple's captive-portal Success body")
    func controlEndpointSuccess() async {
        let check = HTTPSControlEndpointCheck(
            loader: StubControlLoader(
                httpsStatus: 200,
                httpStatus: 200,
                httpBody: "Success"
            )
        )

        let result = await check.run()

        #expect(result.status == .normal)
        #expect(result.evidence.contains(.init(code: "https.available", value: "200")))
        #expect(result.evidence.contains(.init(code: "captive-portal.clear", value: nil)))
    }

    @Test("independent control endpoints load concurrently and preserve evidence order")
    func controlEndpointsRunConcurrently() async {
        let loader = ConcurrentControlLoader()
        let result = await HTTPSControlEndpointCheck(loader: loader).run()

        #expect(await loader.maximumInFlight == 2)
        #expect(result.evidence.map(\.code).prefix(2) == ["https.available", "captive-portal.clear"])
    }

    @Test("control endpoint metrics are redacted to bounded transaction fields")
    func controlEndpointMetricsAreRedacted() async {
        let result = await HTTPSControlEndpointCheck(
            loader: MetricsControlLoader(
                metrics: .init(
                    dnsDuration: .milliseconds(12),
                    connectDuration: .milliseconds(34),
                    tlsDuration: .milliseconds(56),
                    negotiatedTLSVersion: "TLSv1.3",
                    isProxyConnection: true,
                    remoteAddress: "192.0.2.10:443"
                )
            )
        ).run()

        #expect(result.evidence.contains(.init(code: "https.metrics.dns-ms", value: "12")))
        #expect(result.evidence.contains(.init(code: "https.metrics.connect-ms", value: "34")))
        #expect(result.evidence.contains(.init(code: "https.metrics.tls-ms", value: "56")))
        #expect(result.evidence.contains(.init(code: "https.metrics.tls-version", value: "TLSv1.3")))
        #expect(result.evidence.contains(.init(code: "https.metrics.proxy", value: "true")))
        #expect(!result.evidence.contains { $0.value == "192.0.2.10:443" })
    }

    @Test("control endpoint success and captive-portal timeout is indeterminate")
    func controlEndpointMicrosoftTimeoutIsIndeterminate() async {
        let result = await HTTPSControlEndpointCheck(
            loader: StubControlLoader(
                httpsStatus: 200,
                httpStatus: nil,
                httpBody: nil,
                httpErrorCode: String(URLError.timedOut.rawValue)
            )
        ).run()

        #expect(result.status == .indeterminate)
        #expect(result.evidence.contains(.init(code: "https.available", value: "200")))
        #expect(result.evidence.contains(.init(
            code: "captive-portal.transport-error",
            value: String(URLError.timedOut.rawValue)
        )))
    }

    @Test("control endpoint success and captive-portal timeout needs attention")
    func controlEndpointMicrosoftTimeoutConclusion() async {
        let internet = await HTTPSControlEndpointCheck(
            loader: StubControlLoader(
                httpsStatus: 200,
                httpStatus: nil,
                httpBody: nil,
                httpErrorCode: String(URLError.timedOut.rawValue)
            )
        ).run()

        let conclusion = NetworkDiagnosticConclusion.evaluate([
            NetworkDiagnosticResult(id: .path, status: .normal, summary: "path"),
            NetworkDiagnosticResult(id: .gatewayReachability, status: .normal, summary: "gateway"),
            NetworkDiagnosticResult(id: .dns, status: .normal, summary: "dns"),
            internet,
            NetworkDiagnosticResult(id: .ipv6, status: .skipped, summary: "ipv6"),
            NetworkDiagnosticResult(id: .proxy, status: .normal, summary: "proxy"),
        ])

        #expect(conclusion == .needsAttention)
        #expect(conclusion != .networkUnavailable)
    }

    @Test("control endpoint failures retain distinct evidence")
    func controlEndpointFailureEvidence() async {
        let tlsFailure = await HTTPSControlEndpointCheck(
            loader: StubControlLoader(
                httpsStatus: nil,
                httpsErrorCode: String(URLError.secureConnectionFailed.rawValue),
                httpStatus: 200,
                httpBody: "Success"
            )
        ).run()
        let certificateTimeFailure = await HTTPSControlEndpointCheck(
            loader: StubControlLoader(
                httpsStatus: nil,
                httpsErrorCode: String(URLError.serverCertificateNotYetValid.rawValue),
                httpStatus: 200,
                httpBody: "Success"
            )
        ).run()
        let certificateValidationFailure = await HTTPSControlEndpointCheck(
            loader: StubControlLoader(
                httpsStatus: nil,
                httpsErrorCode: String(URLError.serverCertificateUntrusted.rawValue),
                httpStatus: 200,
                httpBody: "Success"
            )
        ).run()
        let connectivityFailure = await HTTPSControlEndpointCheck(
            loader: StubControlLoader(
                httpsStatus: nil,
                httpsErrorCode: String(URLError.timedOut.rawValue),
                httpStatus: 200,
                httpBody: "Success"
            )
        ).run()
        let httpsStatusFailure = await HTTPSControlEndpointCheck(
            loader: StubControlLoader(
                httpsStatus: 503,
                httpStatus: 200,
                httpBody: "Success"
            )
        ).run()
        let captivePortalRedirect = await HTTPSControlEndpointCheck(
            loader: StubControlLoader(
                httpsStatus: 200,
                httpStatus: 302,
                httpBody: nil
            )
        ).run()

        #expect(tlsFailure.evidence.contains(.init(
            code: "https.tls-error",
            value: String(URLError.secureConnectionFailed.rawValue)
        )))
        #expect(certificateTimeFailure.evidence.contains(.init(
            code: "https.certificate-time-error",
            value: String(URLError.serverCertificateNotYetValid.rawValue)
        )))
        #expect(certificateValidationFailure.evidence.contains(.init(
            code: "https.certificate-error",
            value: String(URLError.serverCertificateUntrusted.rawValue)
        )))
        #expect(connectivityFailure.evidence.contains(.init(
            code: "https.connectivity-error",
            value: String(URLError.timedOut.rawValue)
        )))
        #expect(httpsStatusFailure.evidence.contains(.init(code: "https.http-status", value: "503")))
        #expect(captivePortalRedirect.evidence.contains(.init(code: "captive-portal.redirect", value: "302")))
        #expect(tlsFailure.summary == String(
            localized: "network_diagnostics.internet.secure_connection_failure.summary",
            comment: "Network self-check TLS or certificate failure summary"
        ))
        #expect(certificateValidationFailure.summary == tlsFailure.summary)
        #expect(certificateTimeFailure.summary == String(
            localized: "network_diagnostics.internet.certificate_time_failure.summary",
            comment: "Network self-check certificate time failure summary"
        ))
        #expect(connectivityFailure.summary == String(
            localized: "network_diagnostics.internet.connectivity_failure.summary",
            comment: "Network self-check connectivity failure summary"
        ))

        let baseResults = [
            NetworkDiagnosticResult(id: .path, status: .normal, summary: "path"),
            NetworkDiagnosticResult(id: .gatewayReachability, status: .normal, summary: "gateway"),
            NetworkDiagnosticResult(id: .dns, status: .normal, summary: "dns"),
        ]
        let trailingResults = [
            NetworkDiagnosticResult(id: .ipv6, status: .skipped, summary: "ipv6"),
            NetworkDiagnosticResult(id: .proxy, status: .abnormal, summary: "proxy"),
        ]
        #expect(NetworkDiagnosticConclusion.evaluate(
            baseResults + [tlsFailure] + trailingResults
        ) == .needsAttention)
        #expect(NetworkDiagnosticConclusion.evaluate(
            baseResults + [certificateTimeFailure] + trailingResults
        ) == .needsAttention)
        #expect(NetworkDiagnosticConclusion.evaluate(
            baseResults + [certificateValidationFailure] + trailingResults
        ) == .needsAttention)
        #expect(NetworkDiagnosticConclusion.evaluate(
            baseResults + [connectivityFailure] + trailingResults
        ) == .needsAttention)
    }

    @Test("control check loads the approved endpoints with an explicit timeout")
    func controlEndpointRequests() async {
        let recorder = ControlEndpointTestRecorder()
        let check = HTTPSControlEndpointCheck(
            loader: StubControlLoader(
                httpsStatus: 200,
                httpStatus: 200,
                httpBody: "Success",
                recorder: recorder
            )
        )

        _ = await check.run()

        #expect(Set(await recorder.urls) == Set([
            "https://www.apple.com/",
            "https://captive.apple.com/hotspot-detect.html",
        ]))
        #expect(await recorder.timeouts == [.seconds(5), .seconds(5)])
    }

    @Test("system control loader disables caching and connectivity waits")
    func controlEndpointSessionConfiguration() {
        let configuration = SystemControlEndpointLoader.configuration(timeout: .seconds(5))

        #expect(configuration.requestCachePolicy == .reloadIgnoringLocalCacheData)
        #expect(configuration.urlCache == nil)
        #expect(!configuration.waitsForConnectivity)
        #expect(configuration.timeoutIntervalForRequest == 5)
        #expect(configuration.timeoutIntervalForResource == 5)
    }

    @Test("base endpoint configuration does not inherit explicit system proxies")
    func baseEndpointDisablesExplicitSystemProxy() {
        let configuration = SystemControlEndpointLoader.configuration(timeout: .seconds(2))

        #expect(configuration.connectionProxyDictionary?.isEmpty == true)
        #expect(configuration.proxyConfigurations.isEmpty)
    }

    @Test("app scopes the ATS HTTP exception to the Microsoft captive-portal/proxy endpoint")
    func temporaryCaptivePortalATSException() {
        let ats = Bundle.main.object(forInfoDictionaryKey: "NSAppTransportSecurity") as? [String: Any]
        let domains = ats?["NSExceptionDomains"] as? [String: Any]
        let exception = domains?["www.msftconnecttest.com"] as? [String: Any]

        #expect(ats?.count == 1)
        #expect(ats?["NSAllowsArbitraryLoads"] == nil)
        #expect(domains?.count == 1)
        #expect(exception?.count == 1)
        #expect(exception?["NSExceptionAllowsInsecureHTTPLoads"] as? Bool == true)
        #expect(exception?["NSIncludesSubdomains"] == nil)
    }

    @Test("production checks run path DNS HTTPS and proxy in dependency order")
    @MainActor
    func productionCheckOrder() {
        #expect(NetworkDiagnosticsViewModel().checkIDs == [.path, .gatewayReachability, .dns, .internet, .proxy, .ipv6])
    }

    @Test("all successful DNS samples are available")
    func dnsAllSamplesResolved() async {
        let result = await DNSResolutionCheck(resolver: StubDNSResolver(.resolved)).run()

        #expect(result.status == .normal)
        #expect(result.evidence.contains(.init(code: "dns.success-count", value: "3/3")))
        #expect(result.evidence.contains(.init(code: "dns.failure-count", value: "0/3")))
        #expect(result.evidence.contains(.init(code: "dns.indeterminate-count", value: "0/3")))
    }

    @Test("DNS uses the three authoritative third-party probe targets")
    func dnsProbeTargets() {
        let check = DNSResolutionCheck(resolver: StubDNSResolver(.resolved))

        #expect(check.probeTargets == [
            "www.apple.com",
            "www.microsoft.com",
            "www.msftconnecttest.com",
        ])
    }

    @Test("independent DNS samples start concurrently and aggregate in target order")
    func dnsSamplesRunConcurrently() async {
        let resolver = ConcurrentDNSResolver()
        let result = await DNSResolutionCheck(
            resolver: resolver,
            timeout: .seconds(1)
        ).run()

        #expect(await resolver.maximumInFlight == 3)
        #expect(result.evidence.contains(.init(code: "dns.success-count", value: "3/3")))
    }

    @Test("one failed lookup among successful samples is unstable, not unavailable")
    func dnsQuorum() async {
        let check = DNSResolutionCheck(
            resolver: StubDNSResolver(outcomes: [.resolved, .failed, .resolved])
        )

        let result = await check.run()

        #expect(result.status == .indeterminate)
        #expect(result.evidence.contains(.init(code: "dns.success-count", value: "2/3")))
        #expect(result.evidence.contains(.init(code: "dns.failure-count", value: "1/3")))
    }

    @Test("DNS evidence preserves each sample outcome without exposing host names")
    func dnsEvidencePreservesSampleOutcomes() async {
        let result = await DNSResolutionCheck(
            resolver: MappingDNSResolver(outcomes: [
                "www.apple.com": .resolved,
                "www.microsoft.com": .failed,
                "www.msftconnecttest.com": .indeterminate,
            ])
        ).run()

        #expect(result.evidence.contains(.init(code: "dns.sample.apple", value: "resolved")))
        #expect(result.evidence.contains(.init(code: "dns.sample.microsoft", value: "failed")))
        #expect(result.evidence.contains(.init(code: "dns.sample.msft-connect-test", value: "indeterminate")))
        #expect(!result.evidence.contains { $0.value == "www.apple.com" })
    }

    @Test("all failed DNS samples are unavailable")
    func dnsAllSamplesFailed() async {
        let result = await DNSResolutionCheck(resolver: StubDNSResolver(.failed)).run()

        #expect(result.status == .abnormal)
        #expect(result.evidence.contains(.init(code: "dns.success-count", value: "0/3")))
        #expect(result.evidence.contains(.init(code: "dns.failure-count", value: "3/3")))
    }

    @Test("an indeterminate DNS sample is retried once")
    func dnsIndeterminateSampleRetriesOnce() async {
        let resolver = StubDNSResolver(outcomes: [.indeterminate, .resolved, .resolved, .resolved])
        let result = await DNSResolutionCheck(resolver: resolver).run()

        #expect(result.status == .normal)
        #expect(await resolver.invocationCount == 4)
    }

    @Test("cancelling DNS sampling does not retry or exceed one attempt per host")
    func dnsCancellationStopsSampling() async {
        let resolver = CancellationAwareDNSResolver()
        let check = DNSResolutionCheck(resolver: resolver, timeout: .seconds(30))
        let task = Task { await check.run() }

        await resolver.waitForInvocation()
        task.cancel()
        _ = await task.value

        #expect(await resolver.invocationCount <= 3)
    }

    @Test("all indeterminate DNS samples cannot be determined")
    func dnsAllSamplesIndeterminate() async {
        let result = await DNSResolutionCheck(resolver: StubDNSResolver(.indeterminate)).run()

        #expect(result.status == .indeterminate)
        #expect(result.evidence.contains(.init(code: "dns.indeterminate-count", value: "3/3")))
    }

    @Test("DNS success result does not expose the test domain")
    func dnsResultHidesTestDomain() async {
        let testDomain = "example.com"
        let result = await DNSResolutionCheck(
            resolver: StubDNSResolver(.resolved),
            probeTargets: [testDomain, "example.net", "example.org"]
        ).run()

        #expect(!result.summary.localizedCaseInsensitiveContains(testDomain))
    }

    @Test("proxy parser deduplicates HTTP HTTPS and SOCKS endpoints")
    func proxyParsing() {
        let configuration = SystemProxyConfiguration(settings: [
            "HTTPEnable": 1,
            "HTTPProxy": " Proxy.Example ",
            "HTTPPort": 8080,
            "HTTPSEnable": 1,
            "HTTPSProxy": "proxy.example",
            "HTTPSPort": 8080,
            "SOCKSEnable": 1,
            "SOCKSProxy": "socks.example",
            "SOCKSPort": 1080,
        ])

        #expect(configuration.endpoints == [
            ProxyEndpoint(host: "proxy.example", port: 8080),
            ProxyEndpoint(host: "socks.example", port: 1080),
        ])
        #expect(!configuration.hasInvalidExplicitProxy)
    }

    @Test("proxy parser reads PAC URL and automatic discovery")
    func pacParsing() {
        let configuration = SystemProxyConfiguration(settings: [
            "ProxyAutoConfigEnable": 1,
            "ProxyAutoConfigURLString": "https://proxy.example/config.pac",
            "ProxyAutoDiscoveryEnable": 1,
        ])

        #expect(configuration.pacEnabled)
        #expect(configuration.pacURL == "https://proxy.example/config.pac")
        #expect(configuration.autoDiscoveryEnabled)
    }

    @Test("PAC result chooses DIRECT without probing a stale explicit endpoint")
    func pacCanChooseDirect() async {
        let controlURL = URL(string: "http://www.msftconnecttest.com/connecttest.txt")!
        let pacURL = URL(string: "https://proxy.example/config.pac")!
        let recorder = PACResolutionTestRecorder()
        let resolver = SystemProxyResolver(
            pacTimeout: .milliseconds(25),
            configurationResolver: StubProxyConfigurationResolver(.pac(pacURL)),
            pacResolver: StubPACResolver(.direct, recorder: recorder)
        )
        let resolution = await resolver.resolve(for: controlURL)

        #expect(resolution == ProxyCandidateResolution(candidates: [.direct], evidenceCodes: []))
        #expect(await recorder.requests == [
            .init(pacURL: pacURL, targetURL: controlURL, timeout: .milliseconds(25)),
        ])
    }

    @Test("static proxy candidates preserve HTTP then DIRECT order")
    func staticProxyCandidateOrder() {
        let candidates = SystemProxyResolver.candidates(from: [
            proxyDictionary(type: kCFProxyTypeHTTP, host: "127.0.0.1", port: 7890),
            proxyDictionary(type: kCFProxyTypeNone),
        ])

        #expect(candidates == [
            .http(.init(host: "127.0.0.1", port: 7890)),
            .direct,
        ])
    }

    @Test("PAC proxy candidates preserve PROXY then DIRECT order")
    func pacProxyCandidateOrder() {
        let resolution = SystemPACResolver.resolution(from: [
            proxyDictionary(type: kCFProxyTypeHTTP, host: "proxy.example", port: 8080),
            proxyDictionary(type: kCFProxyTypeNone),
        ])

        #expect(resolution == ProxyCandidateResolution(
            candidates: [
                .http(.init(host: "proxy.example", port: 8080)),
                .direct,
            ],
            evidenceCodes: []
        ))
    }

    @Test("inline PAC scripts execute at their ordered directive position")
    func inlinePACScriptPreservesDirectiveOrder() async {
        let target = URL(string: "http://www.msftconnecttest.com/connecttest.txt")!
        let script = "function FindProxyForURL(url, host) { return 'SOCKS proxy.example:1080'; }"
        let first = EffectiveProxy.http(.init(host: "first.example", port: 8080))
        let inline = EffectiveProxy.socks(.init(host: "proxy.example", port: 1080))
        let executor = ControlledPACCallbackExecutor()
        let resolver = SystemProxyResolver(
            configurationResolver: StubProxyConfigurationResolver([
                .http(.init(host: "first.example", port: 8080)),
                .pacScript(script),
                .direct,
            ]),
            pacResolver: SystemPACResolver(callbackExecutor: executor)
        )
        let task = Task { await resolver.resolve(for: target) }

        let request = await executor.nextRequest()
        #expect(request == .init(source: .script(script), targetURL: target))
        executor.complete(.success(.init(candidates: [inline], evidenceCodes: [])))
        let resolution = await task.value

        #expect(resolution == .init(candidates: [first, inline, .direct], evidenceCodes: []))
    }

    @Test("inline PAC dictionaries preserve their JavaScript source")
    func inlinePACDictionaryPreservesScript() {
        let script = "function FindProxyForURL(url, host) { return 'DIRECT'; }"
        let dictionary: NSDictionary = [
            kCFProxyTypeKey as String: kCFProxyTypeAutoConfigurationJavaScript,
            kCFProxyAutoConfigurationJavaScriptKey as String: script,
        ]

        #expect(SystemProxyResolver.directive(from: dictionary) == .pacScript(script))
    }

    @Test("PAC callback errors resume with execution-failed evidence")
    func pacCallbackErrorResumesContinuation() async {
        let target = URL(string: "https://www.apple.com/")!
        let pacURL = URL(string: "https://proxy.example/config.pac")!
        let executor = ControlledPACCallbackExecutor()
        let resolver = SystemPACResolver(callbackExecutor: executor)
        let task = Task {
            await resolver.resolve(pacURL: pacURL, targetURL: target, timeout: .seconds(30))
        }

        let request = await executor.nextRequest()
        #expect(request == .init(source: .url(pacURL), targetURL: target))
        executor.complete(.failure)
        let resolution = await task.value

        #expect(resolution == .init(candidates: [], evidenceCodes: ["pac-execution-failed"]))
        #expect(executor.executionWasCancelled)
    }

    @Test("PAC callback cancellation resumes once with cancellation evidence")
    func pacCallbackCancellationResumesContinuation() async {
        let target = URL(string: "https://www.apple.com/")!
        let pacURL = URL(string: "https://proxy.example/config.pac")!
        let executor = ControlledPACCallbackExecutor()
        let resolver = SystemPACResolver(callbackExecutor: executor)
        let task = Task {
            await resolver.resolve(pacURL: pacURL, targetURL: target, timeout: .seconds(30))
        }

        _ = await executor.nextRequest()
        task.cancel()
        let resolution = await task.value

        #expect(resolution == .init(candidates: [], evidenceCodes: ["pac-cancelled"]))
        #expect(executor.executionWasCancelled)
    }

    @Test("PAC callback timeout resumes once and cancels execution")
    func pacCallbackTimeoutResumesContinuation() async {
        let target = URL(string: "https://www.apple.com/")!
        let pacURL = URL(string: "https://proxy.example/config.pac")!
        let executor = ControlledPACCallbackExecutor()
        let resolver = SystemPACResolver(callbackExecutor: executor)
        let task = Task {
            await resolver.resolve(pacURL: pacURL, targetURL: target, timeout: .milliseconds(10))
        }

        _ = await executor.nextRequest()
        let resolution = await task.value

        #expect(resolution == .init(candidates: [], evidenceCodes: ["pac-timeout"]))
        #expect(executor.executionWasCancelled)
    }

    @Test("invalid proxy candidate preserves later valid candidate and evidence")
    func invalidProxyCandidatePreservesLaterCandidate() async {
        let validProxy = EffectiveProxy.http(.init(host: "proxy.example", port: 8080))
        let resolver = SystemProxyResolver(
            configurationResolver: StubProxyConfigurationResolver(
                SystemProxyResolver.directives(from: [
                    proxyDictionary(type: kCFProxyTypeHTTP),
                    proxyDictionary(
                        type: kCFProxyTypeHTTP,
                        host: "proxy.example",
                        port: 8080
                    ),
                ])
            ),
            pacResolver: StubPACResolver(.direct)
        )

        let resolution = await resolver.resolve(
            for: URL(string: "http://www.msftconnecttest.com/connecttest.txt")!
        )

        #expect(resolution.candidates == [validProxy])
        #expect(resolution.evidenceCodes == ["proxy-endpoint-invalid"])
    }

    @Test("whitespace-only proxy hosts are invalid resolution entries")
    func whitespaceOnlyProxyHostIsInvalid() {
        let directive = SystemProxyResolver.directive(from: proxyDictionary(
            type: kCFProxyTypeHTTP,
            host: " \n\t ",
            port: 8080
        ))

        #expect(directive == .unavailable("proxy-endpoint-invalid"))
    }

    @Test("CFNetwork PAC DIRECT result maps to direct egress")
    func pacDirectParsing() {
        let result: NSDictionary = [
            kCFProxyTypeKey as String: kCFProxyTypeNone,
        ]

        #expect(SystemProxyResolver.directive(from: result) == .direct)
    }

    @Test("DIRECT does not probe a stale explicit endpoint or proxy egress")
    func directSkipsStaleProxy() async {
        let connectorRecorder = ProxyConnectorTestRecorder()
        let egressRecorder = ProxyEgressTestRecorder()
        let check = SystemProxyCheck(
            resolver: StubProxyResolver(.direct),
            connector: RecordingProxyConnector(reachable: false, recorder: connectorRecorder),
            egressLoader: StubProxyEgressLoader(statusCode: nil, errorCode: "unexpected", recorder: egressRecorder),
            tunnelReader: StubProxyTunnelStateReader(interface: nil),
        )

        let result = await check.run()

        #expect(result.status == .indeterminate)
        #expect(await connectorRecorder.endpoints.isEmpty)
        #expect(await egressRecorder.requests.isEmpty)
    }

    @Test("routed tunnel interface is recognized as the proxy route")
    func tunneledRoutingIsRecognized() async {
        let check = SystemProxyCheck(
            resolver: StubProxyResolver(.direct),
            connector: StubProxyConnector(reachable: false),
            egressLoader: StubProxyEgressLoader(statusCode: nil, errorCode: "unexpected"),
            tunnelReader: StubProxyTunnelStateReader(interface: "utun98")
        )

        let result = await check.run()

        #expect(result.status == .normal)
        #expect(result.summary == String(
            localized: "network_diagnostics.proxy.tunnel_routes.summary",
            comment: "Network self-check tunneled proxy route result summary"
        ))
        #expect(result.evidence.contains(.init(code: "proxy.http.route-type", value: "tunnel")))
        #expect(result.evidence.contains(.init(code: "proxy.https.route-type", value: "tunnel")))
        #expect(result.evidence.contains(.init(code: "proxy.http.tunnel-interface", value: "utun98")))
        #expect(result.evidence.contains(.init(code: "proxy.https.tunnel-interface", value: "utun98")))
        #expect(result.evidence.contains(.init(code: "proxy.http.tunnel-detection-source", value: "nwpath")))
        #expect(result.evidence.contains(.init(code: "proxy.https.tunnel-detection-source", value: "nwpath")))
        #expect(result.evidence.contains(.init(code: "proxy.http.egress-status", value: "base-check")))
    }

    @Test("active interface tunnel detection uses the softer summary")
    func activeInterfaceTunnelUsesSofterSummary() async {
        let check = SystemProxyCheck(
            resolver: StubProxyResolver(.direct),
            connector: StubProxyConnector(reachable: false),
            egressLoader: StubProxyEgressLoader(statusCode: nil, errorCode: "unexpected"),
            tunnelReader: StubProxyTunnelStateReader(
                interface: "utun98",
                source: .activeInterface
            )
        )

        let result = await check.run()

        #expect(result.status == .normal)
        #expect(result.summary == String(
            localized: "network_diagnostics.proxy.tunnel_routes_active.summary",
            comment: "Network self-check active tunnel interface proxy route result summary"
        ))
        #expect(result.evidence.contains(.init(code: "proxy.http.route-type", value: "tunnel")))
        #expect(result.evidence.contains(.init(code: "proxy.http.tunnel-detection-source", value: "active-interface")))
        #expect(result.evidence.contains(.init(code: "proxy.https.tunnel-detection-source", value: "active-interface")))
    }

    @Test("tunnel candidate prefers the routed interface then an active ipv4 tunnel")
    func tunnelCandidatePriority() {
        #expect(SystemProxyTunnelStateReader.candidateTunnelState(
            pathRouted: "utun3",
            activeIPv4Tunnels: ["utun98"]
        ) == ProxyTunnelState(interface: "utun3", source: .nwpath))
        #expect(SystemProxyTunnelStateReader.candidateTunnelState(
            pathRouted: nil,
            activeIPv4Tunnels: ["utun98"]
        ) == ProxyTunnelState(interface: "utun98", source: .activeInterface))
        #expect(SystemProxyTunnelStateReader.candidateTunnelState(
            pathRouted: nil,
            activeIPv4Tunnels: []
        ) == nil)
    }

    @Test("tunnel path wait returns nil when the timeout fires before any path")
    func tunnelPathWaitTimeoutWins() async {
        let streamTerminated = LockedFlag()
        let neverEnding = AsyncStream<NWPath> { continuation in
            continuation.onTermination = { _ in streamTerminated.set() }
        }

        let path = await SystemProxyTunnelStateReader.firstPath(
            from: neverEnding,
            timeout: {}
        )

        #expect(path == nil)
        #expect(streamTerminated.isSet)
    }

    @Test("tunnel path wait cancels the pending timeout when the path side completes first")
    func tunnelPathWaitCancelsPendingTimeout() async {
        let probe = TunnelTimeoutCancellationProbe()
        let finished = AsyncStream<NWPath> { continuation in
            continuation.finish()
        }

        let path = await SystemProxyTunnelStateReader.firstPath(
            from: finished,
            timeout: { await probe.park() }
        )

        #expect(path == nil)
        #expect(probe.didCancel)
    }

    @Test("failed proxy candidate falls back to DIRECT for the same target")
    func failedProxyCandidateFallsBackToDirect() async {
        let httpURL = URL(string: "http://www.msftconnecttest.com/connecttest.txt")!
        let httpsURL = URL(string: "https://www.apple.com/")!
        let staleEndpoint = ProxyEndpoint(host: "stale.example", port: 8080)
        let connectorRecorder = ProxyConnectorTestRecorder()
        let egressRecorder = ProxyEgressTestRecorder()
        let check = SystemProxyCheck(
            resolver: RecordingProxyResolver(resolutions: [
                httpURL: .init(candidates: [.http(staleEndpoint), .direct], evidenceCodes: []),
                httpsURL: .init(candidates: [.direct], evidenceCodes: []),
            ]),
            connector: RecordingProxyConnector(reachable: false, recorder: connectorRecorder),
            egressLoader: StubProxyEgressLoader(
                statusCode: 200,
                recorder: egressRecorder
            ),
            tunnelReader: StubProxyTunnelStateReader(interface: nil),
        )

        let result = await check.run()

        #expect(result.status == .indeterminate)
        #expect(result.evidence.contains(.init(code: "proxy.http.endpoint-status", value: "unavailable")))
        #expect(result.evidence.contains(.init(code: "proxy.http.candidate-index", value: "1")))
        #expect(result.evidence.contains(.init(code: "proxy.http.route-type", value: "direct")))
        #expect(result.evidence.contains(.init(code: "proxy.http.fallback-used", value: "true")))
        #expect(await connectorRecorder.endpoints == [staleEndpoint])
        #expect(await egressRecorder.requests.isEmpty)
    }

    @Test("failed first proxy tries the next proxy candidate")
    func failedFirstProxyTriesNextProxy() async {
        let httpURL = URL(string: "http://www.msftconnecttest.com/connecttest.txt")!
        let httpsURL = URL(string: "https://www.apple.com/")!
        let staleEndpoint = ProxyEndpoint(host: "stale.example", port: 8080)
        let workingEndpoint = ProxyEndpoint(host: "working.example", port: 8081)
        let selectedProxy = EffectiveProxy.http(workingEndpoint)
        let connector = SequencedProxyConnector(outcomes: [false, true])
        let egressRecorder = ProxyEgressTestRecorder()
        let check = SystemProxyCheck(
            resolver: RecordingProxyResolver(resolutions: [
                httpURL: .init(
                    candidates: [.http(staleEndpoint), selectedProxy],
                    evidenceCodes: []
                ),
                httpsURL: .init(candidates: [.direct], evidenceCodes: []),
            ]),
            connector: connector,
            egressLoader: StubProxyEgressLoader(statusCode: 204, recorder: egressRecorder),
            tunnelReader: StubProxyTunnelStateReader(interface: nil),
        )

        let result = await check.run()

        #expect(result.status == .indeterminate)
        #expect(await connector.endpoints == [staleEndpoint, workingEndpoint])
        #expect(await egressRecorder.requests.map(\.proxy) == [selectedProxy])
        #expect(result.evidence.contains(.init(code: "proxy.http.candidate-index", value: "1")))
        #expect(result.evidence.contains(.init(code: "proxy.http.fallback-used", value: "true")))
    }

    @Test("candidate attempts share one controlled overall timeout")
    func proxyCandidateAttemptsShareTimeout() async {
        let target = URL(string: "http://www.msftconnecttest.com/connecttest.txt")!
        let firstProxy = EffectiveProxy.http(.init(host: "first.example", port: 8080))
        let secondProxy = EffectiveProxy.http(.init(host: "second.example", port: 8081))
        let connector = SequencedProxyConnector(outcomes: [true, true])
        let egressLoader = SequencedProxyEgressLoader(
            responses: [
                .init(statusCode: nil, errorCode: "timed-out"),
                .init(statusCode: 200, errorCode: nil),
            ],
            delays: [.zero, .zero]
        )
        let clock = SequencedProxyCheckClock(offsets: [
            .zero,
            .zero,
            .milliseconds(250),
            .milliseconds(1_200),
            .milliseconds(1_300),
        ])
        let check = SystemProxyCheck(
            resolver: RecordingProxyResolver(resolutions: [:]),
            connector: connector,
            egressLoader: egressLoader,
            tunnelReader: StubProxyTunnelStateReader(interface: nil),
            timeout: .seconds(2),
            clock: clock
        )

        let result = await check.evaluate(
            target: target,
            resolution: .init(candidates: [firstProxy, secondProxy], evidenceCodes: []),
            timeout: .seconds(2)
        )

        #expect(result.status == .proxied)
        #expect(result.selectedCandidateIndex == 1)
        #expect(result.selectedProxy == secondProxy)
        #expect(await connector.endpoints == [
            .init(host: "first.example", port: 8080),
            .init(host: "second.example", port: 8081),
        ])
        #expect(await connector.timeouts == [.seconds(1), .milliseconds(800)])
        #expect(await egressLoader.timeouts == [.milliseconds(750), .milliseconds(700)])
    }

    @Test("an expired overall proxy timeout does not start another candidate")
    func expiredProxyTimeoutStopsCandidateFallback() async {
        let target = URL(string: "http://www.msftconnecttest.com/connecttest.txt")!
        let firstProxy = EffectiveProxy.http(.init(host: "first.example", port: 8080))
        let secondProxy = EffectiveProxy.http(.init(host: "second.example", port: 8081))
        let connector = SequencedProxyConnector(outcomes: [true, true])
        let egressLoader = SequencedProxyEgressLoader(
            responses: [.init(statusCode: nil, errorCode: "timed-out")],
            delays: [.zero]
        )
        let clock = SequencedProxyCheckClock(offsets: [
            .zero,
            .zero,
            .milliseconds(250),
            .milliseconds(2_100),
        ])
        let check = SystemProxyCheck(
            resolver: RecordingProxyResolver(resolutions: [:]),
            connector: connector,
            egressLoader: egressLoader,
            tunnelReader: StubProxyTunnelStateReader(interface: nil),
            timeout: .seconds(2),
            clock: clock
        )

        let result = await check.evaluate(
            target: target,
            resolution: .init(candidates: [firstProxy, secondProxy], evidenceCodes: []),
            timeout: .seconds(2)
        )

        #expect(result.status == .unavailable)
        #expect(await connector.endpoints == [.init(host: "first.example", port: 8080)])
        #expect(await connector.timeouts == [.seconds(1)])
        #expect(await egressLoader.timeouts == [.milliseconds(750)])
        #expect(result.evidence.contains(.init(code: "proxy.http.timeout", value: "expired")))
    }

    @Test("proxy check resolves the HTTP and HTTPS targets independently")
    func proxyTargetsAreResolvedIndependently() async {
        let recorder = ProxyResolutionTestRecorder()
        let httpURL = URL(string: "http://www.msftconnecttest.com/connecttest.txt")!
        let httpsURL = URL(string: "https://www.apple.com/")!
        let httpsProxy = EffectiveProxy.https(.init(host: "secure-proxy.example", port: 8443))
        let resolver = RecordingProxyResolver(
            resolutions: [
                httpURL: .init(candidates: [.direct], evidenceCodes: []),
                httpsURL: .init(candidates: [httpsProxy], evidenceCodes: []),
            ],
            recorder: recorder
        )
        let check = SystemProxyCheck(
            resolver: resolver,
            connector: StubProxyConnector(reachable: true),
            egressLoader: StubProxyEgressLoader(statusCode: 200),
            tunnelReader: StubProxyTunnelStateReader(interface: nil),
        )

        let result = await check.run()
        let resolvedURLs = await recorder.urls

        #expect(resolvedURLs.count == 2)
        #expect(Set(resolvedURLs) == Set([httpURL.absoluteString, httpsURL.absoluteString]))
        #expect(result.status == .indeterminate)
        #expect(result.summary == String(
            localized: "network_diagnostics.proxy.mixed_routing.summary",
            comment: "Network self-check mixed target proxy routing result summary"
        ))
    }

    @Test("both tested targets can use direct routes without a global disabled claim")
    func bothProxyTargetsDirect() async {
        let recorder = ProxyResolutionTestRecorder()
        let resolver = RecordingProxyResolver(
            defaultResolution: .init(candidates: [.direct], evidenceCodes: []),
            recorder: recorder
        )

        let result = await SystemProxyCheck(
            resolver: resolver,
            connector: StubProxyConnector(reachable: false),
            egressLoader: StubProxyEgressLoader(statusCode: nil, errorCode: "unexpected"),
            tunnelReader: StubProxyTunnelStateReader(interface: nil),
        ).run()

        #expect(result.status == .indeterminate)
        #expect(result.summary == String(
            localized: "network_diagnostics.proxy.direct_routes.summary",
            comment: "Network self-check direct target routes result summary"
        ))
        #expect(result.summary != String(
            localized: "network_diagnostics.proxy.disabled.summary",
            comment: "Network self-check system proxy disabled result summary"
        ))
        #expect(Set(await recorder.urls) == Set([
            "http://www.msftconnecttest.com/connecttest.txt",
            "https://www.apple.com/",
        ]))
    }

    @Test("both tested proxy routes are available")
    func bothProxyTargetsProxied() async {
        let httpURL = URL(string: "http://www.msftconnecttest.com/connecttest.txt")!
        let httpsURL = URL(string: "https://www.apple.com/")!
        let resolver = RecordingProxyResolver(resolutions: [
            httpURL: .init(
                candidates: [.http(.init(host: "proxy.example", port: 8080))],
                evidenceCodes: []
            ),
            httpsURL: .init(
                candidates: [.https(.init(host: "proxy.example", port: 8443))],
                evidenceCodes: []
            ),
        ])

        let result = await SystemProxyCheck(
            resolver: resolver,
            connector: StubProxyConnector(reachable: true),
            egressLoader: StubProxyEgressLoader(statusCode: 200),
            tunnelReader: StubProxyTunnelStateReader(interface: nil),
        ).run()

        #expect(result.status == .normal)
        #expect(result.proxyFacts == .init(http: .available, https: .available))
        #expect(result.summary == String(
            localized: "network_diagnostics.proxy.routes_available.summary",
            comment: "Network self-check proxy target routes available result summary"
        ))
    }

    @Test("a tested target reports proxy authentication required")
    func proxyTargetAuthenticationRequired() async {
        let httpURL = URL(string: "http://www.msftconnecttest.com/connecttest.txt")!
        let httpsURL = URL(string: "https://www.apple.com/")!
        let resolver = RecordingProxyResolver(resolutions: [
            httpURL: .init(
                candidates: [.http(.init(host: "proxy.example", port: 8080))],
                evidenceCodes: []
            ),
            httpsURL: .init(candidates: [.direct], evidenceCodes: []),
        ])

        let result = await SystemProxyCheck(
            resolver: resolver,
            connector: StubProxyConnector(reachable: true),
            egressLoader: StubProxyEgressLoader(statusCode: 407),
            tunnelReader: StubProxyTunnelStateReader(interface: nil),
        ).run()

        #expect(result.status == .abnormal)
        #expect(result.summary == String(
            localized: "network_diagnostics.proxy.authentication_required.summary",
            comment: "Network self-check proxy authentication required result summary"
        ))
        #expect(result.evidence.contains(.init(
            code: "proxy.http.authentication-status",
            value: "required"
        )))
        #expect(result.evidence.contains(.init(code: "proxy.http.egress-status", value: "407")))
    }

    @Test("configured candidates with no working route are unavailable")
    func proxyTargetRouteUnavailable() async {
        let resolver = RecordingProxyResolver(defaultResolution: .init(
            candidates: [.http(.init(host: "stale.example", port: 8080))],
            evidenceCodes: []
        ))

        let result = await SystemProxyCheck(
            resolver: resolver,
            connector: StubProxyConnector(reachable: false),
            egressLoader: StubProxyEgressLoader(statusCode: 200),
            tunnelReader: StubProxyTunnelStateReader(interface: nil),
        ).run()

        #expect(result.status == .abnormal)
        #expect(result.summary == String(
            localized: "network_diagnostics.proxy.route_unavailable.summary",
            comment: "Network self-check proxy target route unavailable result summary"
        ))
        #expect(result.evidence.contains(.init(
            code: "proxy.http.endpoint-status",
            value: "unavailable"
        )))
        #expect(result.evidence.contains(.init(
            code: "proxy.https.endpoint-status",
            value: "unavailable"
        )))
    }

    @Test("empty target resolution is indeterminate")
    func emptyProxyTargetResolutionIsIndeterminate() async {
        let result = await SystemProxyCheck(
            resolver: RecordingProxyResolver(defaultResolution: .init(
                candidates: [],
                evidenceCodes: ["resolution-empty"]
            )),
            connector: StubProxyConnector(reachable: true),
            egressLoader: StubProxyEgressLoader(statusCode: 200),
            tunnelReader: StubProxyTunnelStateReader(interface: nil),
        ).run()

        #expect(result.status == .indeterminate)
        #expect(result.summary == String(
            localized: "network_diagnostics.proxy.unable_to_determine.summary",
            comment: "Network self-check target proxy routing indeterminate result summary"
        ))
        #expect(result.evidence.contains(.init(
            code: "proxy.http.resolution",
            value: "resolution-empty"
        )))
        #expect(result.evidence.contains(.init(
            code: "proxy.https.resolution",
            value: "resolution-empty"
        )))
    }

    @Test("PAC timeout is reported as PAC unavailable")
    func pacTimeout() async {
        let pacURL = URL(string: "https://proxy.example/config.pac")!
        let check = SystemProxyCheck(
            resolver: SystemProxyResolver(
                configurationResolver: StubProxyConfigurationResolver(.pac(pacURL)),
                pacResolver: StubPACResolver(.unavailable("pac-timeout"))
            ),
            connector: StubProxyConnector(reachable: true),
            egressLoader: StubProxyEgressLoader(statusCode: 200),
            tunnelReader: StubProxyTunnelStateReader(interface: nil),
        )

        let result = await check.run()

        #expect(result.status == .indeterminate)
        #expect(result.summary == String(
            localized: "network_diagnostics.proxy.unable_to_determine.summary",
            comment: "Network self-check target proxy routing indeterminate result summary"
        ))
        #expect(result.evidence.contains(.init(code: "proxy.http.resolution", value: "pac-timeout")))
        #expect(result.evidence.contains(.init(code: "proxy.https.resolution", value: "pac-timeout")))
    }

    @Test("selected proxy endpoint failure is distinct from egress failure")
    func selectedProxyEndpointUnavailable() async {
        let egressRecorder = ProxyEgressTestRecorder()
        let proxy = EffectiveProxy.http(ProxyEndpoint(host: "proxy.example", port: 8080))
        let check = SystemProxyCheck(
            resolver: StubProxyResolver(proxy),
            connector: StubProxyConnector(reachable: false),
            egressLoader: StubProxyEgressLoader(statusCode: 200, recorder: egressRecorder),
            tunnelReader: StubProxyTunnelStateReader(interface: nil),
        )

        let result = await check.run()

        #expect(result.status == .abnormal)
        #expect(result.summary == String(
            localized: "network_diagnostics.proxy.route_unavailable.summary",
            comment: "Network self-check proxy target route unavailable result summary"
        ))
        #expect(result.evidence.contains(.init(code: "proxy.endpoint-unavailable", value: nil)))
        #expect(await egressRecorder.requests.isEmpty)
    }

    @Test("HTTP 407 is proxy authentication required")
    func proxyAuthenticationRequired() async {
        let proxy = EffectiveProxy.http(ProxyEndpoint(host: "proxy.example", port: 8080))
        let check = SystemProxyCheck(
            resolver: StubProxyResolver(proxy),
            connector: StubProxyConnector(reachable: true),
            egressLoader: StubProxyEgressLoader(statusCode: 407),
            tunnelReader: StubProxyTunnelStateReader(interface: nil),
        )

        let result = await check.run()

        #expect(result.status == .abnormal)
        #expect(result.summary == String(
            localized: "network_diagnostics.proxy.authentication_required.summary",
            comment: "Network self-check proxy authentication required result summary"
        ))
        #expect(result.evidence.contains(.init(code: "proxy.authentication-required", value: "407")))
        #expect(!result.evidence.contains(where: { $0.code == "proxy.endpoint-unavailable" }))
    }

    @Test("URL loading authentication challenge remains a proxy 407 result")
    func proxyAuthenticationChallenge() {
        let response = SystemProxyEgressLoader.response(
            for: URLError(.userAuthenticationRequired)
        )

        #expect(response == ProxyEgressResponse(statusCode: 407, errorCode: nil))
    }

    @Test("production tunneled egress configuration disables selected proxy failover")
    func selectedProxyDoesNotFailOver() throws {
        let proxy = EffectiveProxy.https(ProxyEndpoint(host: "proxy.example", port: 8080))
        let configuration = try #require(
            SystemProxyEgressLoader.configuration(for: proxy, timeout: .seconds(3))
        )

        #expect(configuration.proxyConfigurations.count == 1)
        #expect(configuration.proxyConfigurations[0].allowFailover == false)
        #expect(configuration.connectionProxyDictionary?.isEmpty != false)
        #expect(configuration.urlCredentialStorage == nil)
    }

    @Test("HTTP forward HTTPS tunnel and SOCKS candidates use distinct transport configurations")
    func selectedProxyTransportConfigurationsPreserveSemantics() throws {
        let endpoint = ProxyEndpoint(host: "proxy.example", port: 8080)
        let httpConfiguration = try #require(SystemProxyEgressLoader.configuration(
            for: .http(endpoint),
            timeout: .seconds(3)
        ))
        let httpsConfiguration = try #require(SystemProxyEgressLoader.configuration(
            for: .https(endpoint),
            timeout: .seconds(3)
        ))
        let socksConfiguration = try #require(SystemProxyEgressLoader.configuration(
            for: .socks(endpoint),
            timeout: .seconds(3)
        ))

        let httpDictionary = try #require(httpConfiguration.connectionProxyDictionary)
        #expect((httpDictionary[kCFNetworkProxiesHTTPEnable as String] as? NSNumber)?.boolValue == true)
        #expect(httpDictionary[kCFNetworkProxiesHTTPProxy as String] as? String == endpoint.host)
        #expect((httpDictionary[kCFNetworkProxiesHTTPPort as String] as? NSNumber)?.intValue == Int(endpoint.port))
        #expect((httpDictionary[kCFNetworkProxiesHTTPSEnable as String] as? NSNumber)?.boolValue == false)
        #expect((httpDictionary[kCFNetworkProxiesSOCKSEnable as String] as? NSNumber)?.boolValue == false)
        #expect((httpDictionary[kCFNetworkProxiesProxyAutoConfigEnable as String] as? NSNumber)?.boolValue == false)
        #expect((httpDictionary[kCFNetworkProxiesProxyAutoDiscoveryEnable as String] as? NSNumber)?.boolValue == false)
        #expect(httpConfiguration.proxyConfigurations.isEmpty)

        #expect(httpsConfiguration.connectionProxyDictionary?.isEmpty == true)
        #expect(httpsConfiguration.proxyConfigurations.count == 1)
        #expect(httpsConfiguration.proxyConfigurations[0].debugDescription.contains("http_connect"))
        #expect(httpsConfiguration.proxyConfigurations[0].allowFailover == false)

        #expect(socksConfiguration.connectionProxyDictionary?.isEmpty == true)
        #expect(socksConfiguration.proxyConfigurations.count == 1)
        #expect(socksConfiguration.proxyConfigurations[0].debugDescription.contains("socksv5"))
        #expect(socksConfiguration.proxyConfigurations[0].allowFailover == false)
    }

    @Test("non-positive proxy timeout without an attempted endpoint is indeterminate")
    func nonPositiveProxyTimeoutIsIndeterminate() async {
        let target = URL(string: "http://www.msftconnecttest.com/connecttest.txt")!
        let endpoint = ProxyEndpoint(host: "proxy.example", port: 8080)
        let connectorRecorder = ProxyConnectorTestRecorder()
        let check = SystemProxyCheck(
            resolver: StubProxyResolver(.direct),
            connector: RecordingProxyConnector(reachable: true, recorder: connectorRecorder),
            egressLoader: StubProxyEgressLoader(statusCode: 200),
            tunnelReader: StubProxyTunnelStateReader(interface: nil),
        )

        let route = await check.evaluate(
            target: target,
            resolution: .init(candidates: [.http(endpoint)], evidenceCodes: []),
            timeout: .zero
        )

        #expect(route.status == .indeterminate)
        #expect(route.selectedCandidateIndex == nil)
        #expect(route.selectedProxy == nil)
        #expect(route.evidence.contains(.init(code: "proxy.http.timeout", value: "expired")))
        #expect(await connectorRecorder.endpoints.isEmpty)
    }

    @Test("later success after 407 selects that candidate and skips the trailing route")
    func proxySuccessAfterAuthenticationShortCircuitsTrailingCandidate() async {
        let target = URL(string: "http://www.msftconnecttest.com/connecttest.txt")!
        let firstEndpoint = ProxyEndpoint(host: "auth.example", port: 8080)
        let selectedEndpoint = ProxyEndpoint(host: "working.example", port: 8081)
        let trailingEndpoint = ProxyEndpoint(host: "unused.example", port: 8082)
        let first = EffectiveProxy.http(firstEndpoint)
        let selected = EffectiveProxy.http(selectedEndpoint)
        let trailing = EffectiveProxy.http(trailingEndpoint)
        let connector = SequencedProxyConnector(outcomes: [true, true, true])
        let egress = SequencedProxyEgressLoader(
            responses: [
                .init(statusCode: 407, errorCode: nil),
                .init(statusCode: 204, errorCode: nil),
                .init(statusCode: 200, errorCode: nil),
            ],
            delays: [.zero, .zero, .zero]
        )
        let check = SystemProxyCheck(
            resolver: StubProxyResolver(.direct),
            connector: connector,
            egressLoader: egress,
            tunnelReader: StubProxyTunnelStateReader(interface: nil),
        )

        let route = await check.evaluate(
            target: target,
            resolution: .init(candidates: [first, selected, trailing], evidenceCodes: []),
            timeout: .seconds(3)
        )

        #expect(route.status == .proxied)
        #expect(route.selectedCandidateIndex == 1)
        #expect(route.selectedProxy == selected)
        #expect(await connector.endpoints == [firstEndpoint, selectedEndpoint])
        #expect(await egress.timeouts.count == 2)
    }

    @Test("authentication evidence takes precedence over an unavailable peer target")
    func proxyMixedFailureSeverityPrefersAuthentication() async {
        let httpURL = URL(string: "http://www.msftconnecttest.com/connecttest.txt")!
        let httpsURL = URL(string: "https://www.apple.com/")!
        let httpProxy = EffectiveProxy.http(.init(host: "auth.example", port: 8080))
        let httpsProxy = EffectiveProxy.https(.init(host: "stale.example", port: 8443))
        let connector = EndpointSelectiveProxyConnector(reachableHosts: ["auth.example"])
        let result = await SystemProxyCheck(
            resolver: RecordingProxyResolver(resolutions: [
                httpURL: .init(candidates: [httpProxy], evidenceCodes: []),
                httpsURL: .init(candidates: [httpsProxy], evidenceCodes: []),
            ]),
            connector: connector,
            egressLoader: StubProxyEgressLoader(statusCode: 407),
            tunnelReader: StubProxyTunnelStateReader(interface: nil),
        ).run()

        #expect(result.status == .abnormal)
        #expect(result.summary == String(
            localized: "network_diagnostics.proxy.authentication_required.summary",
            comment: "Network self-check proxy authentication required result summary"
        ))
        #expect(result.evidence.contains(.init(code: "proxy.http.authentication-status", value: "required")))
        #expect(result.evidence.contains(.init(code: "proxy.https.endpoint-status", value: "unavailable")))
    }

    @Test("selected proxy transport failure is egress unavailable")
    func proxyEgressUnavailable() async {
        let proxy = EffectiveProxy.http(ProxyEndpoint(host: "proxy.example", port: 8080))
        let check = SystemProxyCheck(
            resolver: StubProxyResolver(proxy),
            connector: StubProxyConnector(reachable: true),
            egressLoader: StubProxyEgressLoader(statusCode: nil, errorCode: "-1005"),
            tunnelReader: StubProxyTunnelStateReader(interface: nil),
        )

        let result = await check.run()

        #expect(result.status == .abnormal)
        #expect(result.summary == String(
            localized: "network_diagnostics.proxy.route_unavailable.summary",
            comment: "Network self-check proxy target route unavailable result summary"
        ))
        #expect(result.evidence.contains(.init(code: "proxy.egress-unavailable", value: "-1005")))
    }

    @Test("selected HTTP proxy probes the same control URL once")
    func selectedProxyEgressSuccess() async {
        let controlURL = URL(string: "http://www.msftconnecttest.com/connecttest.txt")!
        let httpsURL = URL(string: "https://www.apple.com/")!
        let proxy = EffectiveProxy.http(ProxyEndpoint(host: "proxy.example", port: 8080))
        let recorder = ProxyEgressTestRecorder()
        let check = SystemProxyCheck(
            resolver: RecordingProxyResolver(resolutions: [
                controlURL: .init(candidates: [proxy], evidenceCodes: []),
                httpsURL: .init(candidates: [.direct], evidenceCodes: []),
            ]),
            connector: StubProxyConnector(reachable: true),
            egressLoader: StubProxyEgressLoader(statusCode: 200, recorder: recorder),
            tunnelReader: StubProxyTunnelStateReader(interface: nil),
        )

        let result = await check.run()

        #expect(result.status == .indeterminate)
        #expect(await recorder.requests == [.init(url: controlURL, proxy: proxy)])
    }

    @Test("cancelled concurrent proxy resolution remains bounded")
    func proxyCancellationStopsSecondTargetResolution() async {
        let resolver = CancellationIgnoringProxyResolver()
        let check = SystemProxyCheck(
            resolver: resolver,
            connector: StubProxyConnector(reachable: true),
            egressLoader: StubProxyEgressLoader(statusCode: 200),
            tunnelReader: StubProxyTunnelStateReader(interface: nil),
        )
        let task = Task { await check.run() }

        await resolver.waitForInvocation()
        task.cancel()
        let result = await task.value

        #expect(await resolver.urls.count <= 2)
        #expect(result.status == .indeterminate)
        #expect(result.evidence.contains(.init(
            code: "proxy.cancelled",
            value: "after-http-resolution"
        )))
    }

    @Test("cancelled PAC resolution does not append later static candidates")
    func proxyResolverCancellationStopsRemainingDirectives() async {
        let pacURL = URL(string: "https://proxy.example/config.pac")!
        let pacResolver = CancellationIgnoringPACResolver()
        let resolver = SystemProxyResolver(
            configurationResolver: StubProxyConfigurationResolver([
                .pac(pacURL),
                .http(.init(host: "unused.example", port: 8080)),
            ]),
            pacResolver: pacResolver
        )
        let task = Task {
            await resolver.resolve(
                for: URL(string: "http://www.msftconnecttest.com/connecttest.txt")!
            )
        }

        await pacResolver.waitForInvocation()
        task.cancel()
        let resolution = await task.value

        #expect(resolution.candidates.isEmpty)
        #expect(resolution.evidenceCodes.contains("pac-cancelled"))
        #expect(resolution.evidenceCodes.contains("resolution-cancelled"))
    }

    @Test("cancelling an endpoint attempt stops candidate fallback")
    func proxyCancellationStopsAfterConnector() async {
        let target = URL(string: "http://www.msftconnecttest.com/connecttest.txt")!
        let first = ProxyEndpoint(host: "first.example", port: 8080)
        let second = ProxyEndpoint(host: "second.example", port: 8081)
        let connector = CancellationIgnoringProxyConnector()
        let check = SystemProxyCheck(
            resolver: StubProxyResolver(.direct),
            connector: connector,
            egressLoader: StubProxyEgressLoader(statusCode: 200),
            tunnelReader: StubProxyTunnelStateReader(interface: nil),
        )
        let task = Task {
            await check.evaluate(
                target: target,
                resolution: .init(candidates: [.http(first), .http(second)], evidenceCodes: []),
                timeout: .seconds(30)
            )
        }

        await connector.waitForInvocation()
        task.cancel()
        let route = await task.value

        #expect(await connector.endpoints == [first])
        #expect(route.status == .indeterminate)
        #expect(route.evidence.contains(.init(
            code: "proxy.http.cancelled",
            value: "endpoint"
        )))
    }

    @Test("cancelling proxy egress stops connector and candidate fallback")
    func proxyCancellationStopsAfterEgress() async {
        let target = URL(string: "http://www.msftconnecttest.com/connecttest.txt")!
        let first = ProxyEndpoint(host: "first.example", port: 8080)
        let second = ProxyEndpoint(host: "second.example", port: 8081)
        let connector = SequencedProxyConnector(outcomes: [true, true])
        let egress = CancellationIgnoringProxyEgressLoader()
        let check = SystemProxyCheck(
            resolver: StubProxyResolver(.direct),
            connector: connector,
            egressLoader: egress,
            tunnelReader: StubProxyTunnelStateReader(interface: nil),
        )
        let task = Task {
            await check.evaluate(
                target: target,
                resolution: .init(candidates: [.http(first), .http(second)], evidenceCodes: []),
                timeout: .seconds(30)
            )
        }

        await egress.waitForInvocation()
        task.cancel()
        let route = await task.value

        #expect(await connector.endpoints == [first])
        #expect(await egress.invocationCount == 1)
        #expect(route.status == .indeterminate)
        #expect(route.evidence.contains(.init(
            code: "proxy.http.cancelled",
            value: "egress"
        )))
    }

    @Test("view model starts idle and only runs after start")
    @MainActor
    func viewModelManualStart() async {
        let recorder = DiagnosticTestRecorder()
        let guidance = IsolatedGuidance()
        let viewModel = NetworkDiagnosticsViewModel(
            checks: makeStubChecks(recorder: recorder),
            minimumStepDuration: .zero,
            fingerprintMonitor: DisabledNetworkFingerprintMonitor(),
            guidance: guidance.coordinator
        )

        #expect(viewModel.phase == .idle)
        #expect(viewModel.conclusion == nil)
        #expect(await recorder.values.isEmpty)

        #expect(viewModel.start())
        #expect(!viewModel.start())
        await viewModel.waitForCompletion()

        #expect(viewModel.phase == .completed)
        #expect(viewModel.conclusion == .networkNormal)
        #expect(viewModel.results.count == 3)
        #expect(viewModel.executionPhases.values.allSatisfy { $0 == .completed })
    }

    @Test("network diagnostics keeps an isolated resettable log buffer")
    func networkDiagnosticsLogStoreIsResettable() {
        var store = NetworkDiagnosticsLogStore()

        store.append("self-check started")
        store.append("DNS resolved")

        #expect(store.lines == ["self-check started", "DNS resolved"])
        #expect(store.text == "self-check started\nDNS resolved")

        store.reset()

        #expect(store.lines.isEmpty)
        #expect(store.text.isEmpty)
    }

    @Test("diagnostics log store keeps a bounded history and truncation marker")
    func diagnosticsLogStoreHasFiniteCapacity() {
        var store = NetworkDiagnosticsLogStore()

        for index in 0..<501 {
            store.append("event \(index)")
        }

        #expect(store.lines.count == NetworkDiagnosticsLogStore.capacity)
        #expect(store.lines.contains(NetworkDiagnosticsLogStore.truncationMarker))
        #expect(!store.text.contains("event 0\n"))
        #expect(store.text.contains("event 500"))

        var typedStore = NetworkDiagnosticsLogStore()
        for index in 0..<501 {
            typedStore.append(NetworkDiagnosticEvent(
                runID: UUID(),
                elapsedMilliseconds: Int64(index),
                kind: .checkFinished,
                checkID: .path,
                reasonCode: nil
            ))
        }
        #expect(typedStore.lines.count == NetworkDiagnosticsLogStore.capacity)
        #expect(typedStore.events.count == NetworkDiagnosticsLogStore.capacity - 1)
    }

    @Test("typed diagnostic events only format allowlisted restart reasons")
    func diagnosticEventFormattingAllowlist() {
        let event = NetworkDiagnosticEvent(
            runID: UUID(),
            elapsedMilliseconds: 42,
            kind: .restarted,
            checkID: nil,
            reasonCode: "raw-sensitive-value"
        )

        #expect(event.formatted() == "42ms · Network changed; restarting (network state)")
        #expect(!event.formatted().contains("raw-sensitive-value"))
    }

    @Test("view model publishes its own diagnostic result logs")
    @MainActor
    func viewModelPublishesDiagnosticLogs() async {
        let viewModel = NetworkDiagnosticsViewModel(
            checks: makeStubChecks(recorder: DiagnosticTestRecorder()),
            minimumStepDuration: .zero,
            fingerprintMonitor: DisabledNetworkFingerprintMonitor()
        )

        #expect(viewModel.logText.isEmpty)
        #expect(viewModel.start())
        await viewModel.waitForCompletion()

        let stableLogLines = viewModel.logStore.lines.map { line in
            guard let separator = line.range(of: " · ") else { return line }
            return String(line[separator.upperBound...])
        }
        #expect(stableLogLines == [
            "Session started",
            "Run started",
            "Checking Network Path…",
            "Network Path finished",
            "Checking DNS Resolution…",
            "DNS Resolution finished",
            "Checking System Proxy…",
            "System Proxy finished",
            "Check completed",
        ])
        #expect(viewModel.logStore.events.map(\.kind) == [
            .sessionStarted,
            .runStarted,
            .checkStarted,
            .checkFinished,
            .checkStarted,
            .checkFinished,
            .checkStarted,
            .checkFinished,
            .completed,
        ])

        viewModel.clearLogs()
        #expect(viewModel.logText.isEmpty)
    }

    @Test("view model clears the previous conclusion before a rerun")
    @MainActor
    func viewModelRerun() async {
        let recorder = DiagnosticTestRecorder()
        let guidance = IsolatedGuidance()
        let viewModel = NetworkDiagnosticsViewModel(
            checks: makeStubChecks(recorder: recorder),
            minimumStepDuration: .zero,
            fingerprintMonitor: DisabledNetworkFingerprintMonitor(),
            guidance: guidance.coordinator
        )

        #expect(viewModel.start())
        await viewModel.waitForCompletion()
        #expect(viewModel.conclusion == .networkNormal)

        #expect(viewModel.start())
        #expect(viewModel.conclusion == nil)
        await viewModel.waitForCompletion()
        #expect(await recorder.values.count == 6)
    }

    @Test("a changed fingerprint restarts network probes once and retains configuration results")
    @MainActor
    func fingerprintChangeRestartsOnce() async {
        let initial = makeFingerprint(interfaceName: "en0", dnsHash: 1)
        let fingerprintMonitor = ControlledNetworkFingerprintMonitor(initial: initial)
        let guidance = IsolatedGuidance()
        let configurationProbe = RestartableDiagnosticProbe()
        let networkProbe = RestartableDiagnosticProbe(blockFirstInvocation: true)
        let checks: [any DiagnosticCheck] = [
            ProbeDiagnosticCheck(
                id: .proxy,
                result: .init(id: .proxy, status: .normal, summary: "configuration"),
                rerunPolicy: .configurationOnly,
                probe: configurationProbe
            ),
            ProbeDiagnosticCheck(
                id: .path,
                result: .init(id: .path, status: .normal, summary: "network"),
                rerunPolicy: .networkSensitive,
                probe: networkProbe
            ),
        ]
        let viewModel = NetworkDiagnosticsViewModel(
            checks: checks,
            minimumStepDuration: .zero,
            fingerprintMonitor: fingerprintMonitor,
            guidance: guidance.coordinator
        )

        #expect(viewModel.start())
        await networkProbe.waitForInvocationCount(1)
        await fingerprintMonitor.send(makeFingerprint(interfaceName: "en1", dnsHash: 2))
        await fingerprintMonitor.send(makeFingerprint(interfaceName: "en2", dnsHash: 3))
        await viewModel.waitForCompletion()

        #expect(viewModel.phase == .completed)
        #expect(viewModel.conclusion == .networkNormal)
        #expect(viewModel.automaticRestartCount == 1)
        #expect(await configurationProbe.invocationCount == 1)
        #expect(await networkProbe.invocationCount == 2)
        #expect(viewModel.results[.proxy]?.summary == "configuration")
        #expect(viewModel.results[.path]?.summary == "network")
    }

    @Test("an unchanged fingerprint does not restart an active probe")
    @MainActor
    func unchangedFingerprintDoesNotRestart() async {
        let fingerprint = makeFingerprint(interfaceName: "en0", dnsHash: 1)
        let fingerprintMonitor = ControlledNetworkFingerprintMonitor(initial: fingerprint)
        let guidance = IsolatedGuidance()
        let probe = RestartableDiagnosticProbe(blockFirstInvocation: true)
        let viewModel = NetworkDiagnosticsViewModel(
            checks: [
                ProbeDiagnosticCheck(
                    id: .path,
                    result: .init(id: .path, status: .normal, summary: "network"),
                    rerunPolicy: .networkSensitive,
                    probe: probe
                ),
            ],
            minimumStepDuration: .zero,
            fingerprintMonitor: fingerprintMonitor,
            guidance: guidance.coordinator
        )

        #expect(viewModel.start())
        await probe.waitForInvocationCount(1)
        await fingerprintMonitor.send(fingerprint)
        await probe.releaseFirstInvocation()
        await viewModel.waitForCompletion()

        #expect(viewModel.automaticRestartCount == 0)
        #expect(await probe.invocationCount == 1)
    }

    @Test("a second network change during the rerun starts a fresh run")
    @MainActor
    func repeatedFingerprintChangesRestartAgain() async {
        let initial = makeFingerprint(interfaceName: "en0", dnsHash: 1)
        let fingerprintMonitor = ControlledNetworkFingerprintMonitor(initial: initial)
        let probe = BlockingDiagnosticProbe()
        let guidance = IsolatedGuidance()
        let viewModel = NetworkDiagnosticsViewModel(
            checks: [BlockingProbeDiagnosticCheck(id: .path, probe: probe)],
            minimumStepDuration: .zero,
            fingerprintMonitor: fingerprintMonitor,
            guidance: guidance.coordinator
        )

        #expect(viewModel.start())
        await probe.waitForInvocationCount(1)
        await fingerprintMonitor.send(makeFingerprint(interfaceName: "en1", dnsHash: 2))
        await probe.waitForInvocationCount(2)
        await fingerprintMonitor.send(makeFingerprint(interfaceName: "en2", dnsHash: 3))
        await probe.waitForInvocationCount(3)
        await probe.release(invocation: 3)
        await viewModel.waitForCompletion()

        #expect(viewModel.phase == .completed)
        #expect(viewModel.automaticRestartCount == 2)
        #expect(await probe.invocationCount == 3)
    }

    @Test("the controller closes network-change intake before results are published")
    func fingerprintControllerFinalizationGate() async {
        let controller = NetworkDiagnosticRestartController()
        let fingerprint = makeFingerprint(interfaceName: "en1", dnsHash: 2)

        #expect(await controller.completeRun() == false)
        #expect(await controller.observe(fingerprint) == false)
    }

    @Test("stability window starts from the latest network change")
    func stabilityWindowUsesLatestChange() async {
        let controller = NetworkDiagnosticRestartController()
        let base = ContinuousClock.now
        let first = makeFingerprint(interfaceName: "en1", dnsHash: 2)
        let second = makeFingerprint(interfaceName: "en2", dnsHash: 3)

        #expect(await controller.observe(first, at: base))
        let waitTask = Task {
            await controller.waitForStability(
                using: ContinuousDiagnosticClock(),
                until: base.advanced(by: .seconds(2))
            )
        }

        try? await Task.sleep(for: .milliseconds(400))
        #expect(await controller.observe(
            second,
            at: base.advanced(by: .milliseconds(400))
        ))

        let completedBeforeLatestWindow = await withTaskGroup(of: Bool.self) { group in
            group.addTask {
                await waitTask.value
                return true
            }
            group.addTask {
                do {
                    try await Task.sleep(for: .milliseconds(400))
                } catch {
                    return false
                }
                return false
            }
            let result = await group.next() ?? false
            group.cancelAll()
            return result
        }

        #expect(!completedBeforeLatestWindow)
        await controller.cancelCurrentRun()
        _ = await waitTask.value
    }

    @Test("explicit cancellation is latched before a run is installed")
    func restartControllerLatchesCancellationBeforeInstall() async {
        let controller = NetworkDiagnosticRestartController()
        let run = Task<[NetworkDiagnosticResult], Never> {
            try? await Task.sleep(for: .seconds(30))
            return []
        }

        await controller.cancelCurrentRun()
        await controller.install(run)

        #expect(run.isCancelled)
        run.cancel()
        _ = await run.value
    }

    @Test("a duplicate path update is ignored")
    func duplicatePathUpdateIsIgnored() async throws {
        let baseline = makeFingerprint(interfaceName: "en0", dnsHash: 1)
        let path = NetworkPathFingerprint(
            interfaceType: baseline.interfaceType,
            interfaceName: baseline.interfaceName,
            pathStatus: baseline.pathStatus
        )
        let monitor = SystemNetworkFingerprintMonitor(
            settingsReader: MutableFingerprintSettingsReader(dnsHash: 1, proxyHash: 7),
            pathSource: FiniteNetworkPathFingerprintSource(values: [path, path]),
            settingsPoller: SilentNetworkFingerprintSettingsPoller()
        )

        let optionalObservation = await monitor.observation()
        let observation = try #require(optionalObservation)
        var changes: [NetworkFingerprint] = []
        for await fingerprint in observation.changes {
            changes.append(fingerprint)
        }

        #expect(observation.baseline == baseline)
        #expect(changes.isEmpty)
    }

    @Test("baseline and an immediate path change share one buffered observation source")
    func fingerprintObservationDoesNotLoseBaselineGapChange() async throws {
        let baselinePath = NetworkPathFingerprint(
            interfaceType: "wifi",
            interfaceName: "en0",
            pathStatus: .satisfied
        )
        let changedPath = NetworkPathFingerprint(
            interfaceType: "wifi",
            interfaceName: "en1",
            pathStatus: .satisfied
        )
        let pathSource = BufferedGapNetworkPathFingerprintSource(
            values: [baselinePath, changedPath]
        )
        let monitor = SystemNetworkFingerprintMonitor(
            settingsReader: MutableFingerprintSettingsReader(dnsHash: 1, proxyHash: 7),
            pathSource: pathSource,
            settingsPoller: SilentNetworkFingerprintSettingsPoller()
        )

        let optionalObservation = await monitor.observation()
        let observation = try #require(optionalObservation)
        var iterator = observation.changes.makeAsyncIterator()
        let change = await iterator.next()

        #expect(observation.baseline.interfaceName == "en0")
        #expect(change?.interfaceName == "en1")
        #expect(pathSource.streamRequestCount == 1)
    }

    @Test("explicit cancellation stops an active diagnostics session")
    @MainActor
    func viewModelCancellation() async {
        let probe = BlockingDiagnosticProbe()
        let viewModel = NetworkDiagnosticsViewModel(
            checks: [BlockingProbeDiagnosticCheck(id: .path, probe: probe)],
            minimumStepDuration: .zero,
            fingerprintMonitor: DisabledNetworkFingerprintMonitor()
        )

        #expect(viewModel.start())
        await probe.waitForInvocationCount(1)
        viewModel.cancel()
        await viewModel.waitForCompletion()

        #expect(viewModel.phase == .completed)
        #expect(viewModel.conclusion == nil)
        #expect(viewModel.endReason == .cancelled)
    }

    @Test("a cancelled run cannot overwrite a replacement run")
    @MainActor
    func cancelledRunCannotOverwriteReplacementRun() async {
        let probe = CancellationIgnoringDiagnosticProbe()
        let viewModel = NetworkDiagnosticsViewModel(
            checks: [CancellationIgnoringProbeDiagnosticCheck(probe: probe)],
            minimumStepDuration: .zero,
            fingerprintMonitor: DisabledNetworkFingerprintMonitor()
        )

        #expect(viewModel.start())
        await probe.waitForInvocationCount(1)
        viewModel.cancel()
        #expect(viewModel.start())
        await probe.waitForInvocationCount(2)

        await probe.release(invocation: 1)
        try? await Task.sleep(for: .milliseconds(10))
        #expect(viewModel.phase == .running)
        #expect(viewModel.results.isEmpty)

        await probe.release(invocation: 2)
        await viewModel.waitForCompletion()

        #expect(viewModel.phase == .completed)
        #expect(viewModel.endReason == .completed)
        #expect(viewModel.results[.path]?.status == .normal)
    }

    @Test("unstable network changes do not restore invalidated results")
    @MainActor
    func unstableNetworkChangeDoesNotRestoreOldResults() async {
        let initial = makeFingerprint(interfaceName: "en0", dnsHash: 1)
        let fingerprintMonitor = ControlledNetworkFingerprintMonitor(initial: initial)
        let blockingProbe = BlockingDiagnosticProbe()
        let clock = ManualDiagnosticClock()
        let viewModel = NetworkDiagnosticsViewModel(
            checks: [
                StubDiagnosticCheck(
                    id: .path,
                    result: .init(id: .path, status: .normal, summary: "old path"),
                    recorder: DiagnosticTestRecorder()
                ),
                BlockingProbeDiagnosticCheck(id: .dns, probe: blockingProbe),
            ],
            minimumStepDuration: .zero,
            fingerprintMonitor: fingerprintMonitor,
            clock: clock
        )

        #expect(viewModel.start())
        await blockingProbe.waitForInvocationCount(1)
        await clock.set(clock.origin.advanced(by: .milliseconds(29_800)))
        await fingerprintMonitor.send(makeFingerprint(interfaceName: "en1", dnsHash: 1))
        await clock.set(clock.origin.advanced(by: .milliseconds(30_100)))
        await viewModel.waitForCompletion()

        #expect(viewModel.phase == .completed)
        #expect(viewModel.endReason == .superseded)
        #expect(viewModel.results.isEmpty)
        #expect(viewModel.pendingCheckIDs == [.path, .dns])
    }

    @Test("a successful diagnostics run reports the completion moment exactly once")
    @MainActor
    func successfulRunReportsDiagnosticsMomentOnce() async {
        let recorder = DiagnosticTestRecorder()
        let guidance = IsolatedGuidance()
        let viewModel = NetworkDiagnosticsViewModel(
            checks: makeStubChecks(recorder: recorder),
            minimumStepDuration: .zero,
            fingerprintMonitor: DisabledNetworkFingerprintMonitor(),
            guidance: guidance.coordinator
        )

        #expect(viewModel.start())
        await viewModel.waitForCompletion()

        #expect(viewModel.phase == .completed)
        let loaded = guidance.store.load()
        #expect(loaded.meaningfulCompletionCount == 1)
        #expect(loaded.invitationPresentationCount == 0)
        #expect(loaded.lastInvitationDate == nil)
        #expect(guidance.events.filter { $0.name == "guidance.value_moment" }.count == 1)
    }

    @Test("a run that never reaches completion never reports the diagnostics moment")
    @MainActor
    func failingRunNeverReportsDiagnosticsMoment() async {
        let probe = BlockingDiagnosticProbe()
        let guidance = IsolatedGuidance()
        let viewModel = NetworkDiagnosticsViewModel(
            checks: [BlockingProbeDiagnosticCheck(id: .path, probe: probe)],
            minimumStepDuration: .zero,
            fingerprintMonitor: DisabledNetworkFingerprintMonitor(),
            guidance: guidance.coordinator
        )

        #expect(viewModel.start())
        await probe.waitForInvocationCount(1)
        viewModel.cancel()
        await viewModel.waitForCompletion()

        #expect(viewModel.phase == .completed)
        #expect(viewModel.conclusion == nil)
        #expect(viewModel.endReason == .cancelled)
        #expect(guidance.store.load().meaningfulCompletionCount == 0)
        #expect(guidance.events.isEmpty)
    }

    @Test("system fingerprint monitor detects DNS settings changes without a path update")
    func fingerprintDetectsSettingsOnlyChange() async throws {
        let baseline = makeFingerprint(interfaceName: "en0", dnsHash: 1)
        let path = NetworkPathFingerprint(
            interfaceType: baseline.interfaceType,
            interfaceName: baseline.interfaceName,
            pathStatus: baseline.pathStatus
        )
        let settingsReader = SequencedFingerprintSettingsReader(dnsHashes: [1, 2], proxyHash: 7)
        let monitor = SystemNetworkFingerprintMonitor(
            settingsReader: settingsReader,
            pathSource: FiniteNetworkPathFingerprintSource(values: [path]),
            settingsPoller: ImmediateNetworkFingerprintSettingsPoller(),
            settingsPollInterval: .milliseconds(10)
        )

        let optionalObservation = await monitor.observation()
        let observation = try #require(optionalObservation)
        var iterator = observation.changes.makeAsyncIterator()
        let changedFingerprint = await iterator.next()

        #expect(observation.baseline == baseline)
        #expect(changedFingerprint?.interfaceName == "en0")
        #expect(changedFingerprint?.dnsSettingsHash == 2)
        #expect(changedFingerprint?.staticProxySettingsHash == 7)
    }

    @Test("system fingerprint monitor detects route changes without DNS or proxy changes")
    func fingerprintDetectsRouteOnlyChange() async throws {
        let baselinePath = NetworkPathFingerprint(
            interfaceType: "ethernet",
            interfaceName: "en7",
            pathStatus: .satisfied
        )
        let routeSource = SequencedFingerprintRouteStateSource(values: [
            NetworkFingerprintRouteState(
                interfaceName: "en7",
                interfaceIndex: 12,
                gateway: "192.0.2.1",
                addresses: ["192.0.2.10"],
                subnets: ["255.255.255.0"]
            ),
            NetworkFingerprintRouteState(
                interfaceName: "en7",
                interfaceIndex: 12,
                gateway: "192.0.2.254",
                addresses: ["192.0.2.10"],
                subnets: ["255.255.255.0"]
            ),
            NetworkFingerprintRouteState(
                interfaceName: nil,
                interfaceIndex: nil,
                gateway: nil
            ),
        ])
        let monitor = SystemNetworkFingerprintMonitor(
            settingsReader: MutableFingerprintSettingsReader(dnsHash: 1, proxyHash: 7),
            pathSource: FiniteNetworkPathFingerprintSource(values: [baselinePath]),
            settingsPoller: FixedCountNetworkFingerprintSettingsPoller(count: 2),
            routeStateSource: routeSource
        )

        let observation = try #require(await monitor.observation())
        var iterator = observation.changes.makeAsyncIterator()
        let change = await iterator.next()
        let disappeared = await iterator.next()

        #expect(observation.baseline.selectedGateway == "192.0.2.1")
        #expect(change?.selectedGateway == "192.0.2.254")
        #expect(disappeared?.selectedGateway == nil)
        #expect(disappeared?.selectedInterfaceIndex == nil)
        #expect(disappeared?.selectedInterfaceAddresses.isEmpty == true)
    }

    @Test("proxy fingerprint includes PAC and automatic discovery settings")
    func proxyFingerprintIncludesAutomaticSettings() {
        let baseline = SystemNetworkFingerprintSettingsReader.proxySettingsHash(for: [
            "ProxyAutoConfigEnable": 0,
            "ProxyAutoConfigURLString": "https://proxy.example/old.pac",
            "ProxyAutoDiscoveryEnable": 0,
        ])
        let changedPAC = SystemNetworkFingerprintSettingsReader.proxySettingsHash(for: [
            "ProxyAutoConfigEnable": 1,
            "ProxyAutoConfigURLString": "https://proxy.example/new.pac",
            "ProxyAutoDiscoveryEnable": 0,
        ])
        let changedDiscovery = SystemNetworkFingerprintSettingsReader.proxySettingsHash(for: [
            "ProxyAutoConfigEnable": 0,
            "ProxyAutoConfigURLString": "https://proxy.example/old.pac",
            "ProxyAutoDiscoveryEnable": 1,
        ])

        #expect(changedPAC != baseline)
        #expect(changedDiscovery != baseline)
    }

    @Test("VPN and TUN interface names are classified without VPN manager access")
    func tunnelInterfaceClassification() {
        let tunnels = NetworkTunnelInterfaceClassifier.tunnelInterfaces(from: [
            "en0", "utun3", "ipsec0", "ppp0", "bridge0", "utun2"
        ])

        #expect(tunnels == ["ipsec0", "ppp0", "utun2", "utun3"])
        #expect(NetworkTunnelInterfaceClassifier.routedTunnelInterface(
            activeInterfaceName: "utun3",
            tunnelInterfaces: tunnels
        ) == "utun3")
        #expect(NetworkTunnelInterfaceClassifier.routedTunnelInterface(
            activeInterfaceName: "en0",
            tunnelInterfaces: tunnels
        ) == nil)
    }

    @Test("tunnel presence and routed interface changes are fingerprint changes")
    func tunnelFingerprintChangesTriggerObservation() async throws {
        let baselinePath = NetworkPathFingerprint(
            interfaceType: "wifi",
            interfaceName: "en0",
            pathStatus: .satisfied,
            tunnelInterfaces: [],
            routedTunnelInterface: nil
        )
        let changedPath = NetworkPathFingerprint(
            interfaceType: "wifi",
            interfaceName: "en0",
            pathStatus: .satisfied,
            tunnelInterfaces: ["utun3"],
            routedTunnelInterface: "utun3"
        )
        let monitor = SystemNetworkFingerprintMonitor(
            settingsReader: MutableFingerprintSettingsReader(dnsHash: 1, proxyHash: 7),
            pathSource: FiniteNetworkPathFingerprintSource(values: [baselinePath, changedPath]),
            settingsPoller: SilentNetworkFingerprintSettingsPoller()
        )

        let observation = try #require(await monitor.observation())
        var iterator = observation.changes.makeAsyncIterator()
        let change = await iterator.next()

        #expect(observation.baseline.tunnelInterfaces.isEmpty)
        #expect(change?.tunnelInterfaces == ["utun3"])
        #expect(change?.routedTunnelInterface == "utun3")
    }

    @Test("gateway target identity includes interface index and address state")
    func fingerprintIncludesRouteAndAddressIdentity() {
        let first = NetworkFingerprint(
            interfaceType: "ethernet",
            interfaceName: "en7",
            pathStatus: .satisfied,
            dnsSettingsHash: 1,
            staticProxySettingsHash: 7,
            selectedInterfaceIndex: 12,
            selectedInterfaceAddresses: ["192.0.2.10"],
            selectedInterfaceSubnets: ["255.255.255.0"],
            selectedGateway: "192.0.2.1",
            ipv4PrimaryServiceIdentity: "service-a",
            ipv6PrimaryServiceIdentity: "service-v6"
        )
        let changedAddress = NetworkFingerprint(
            interfaceType: "ethernet",
            interfaceName: "en7",
            pathStatus: .satisfied,
            dnsSettingsHash: 1,
            staticProxySettingsHash: 7,
            selectedInterfaceIndex: 12,
            selectedInterfaceAddresses: ["192.0.2.11"],
            selectedInterfaceSubnets: ["255.255.255.0"],
            selectedGateway: "192.0.2.1",
            ipv4PrimaryServiceIdentity: "service-a",
            ipv6PrimaryServiceIdentity: "service-v6"
        )
        let changedRoute = NetworkFingerprint(
            interfaceType: "ethernet",
            interfaceName: "en7",
            pathStatus: .satisfied,
            dnsSettingsHash: 1,
            staticProxySettingsHash: 7,
            selectedInterfaceIndex: 12,
            selectedInterfaceAddresses: ["192.0.2.10"],
            selectedInterfaceSubnets: ["255.255.255.0"],
            selectedGateway: "192.0.2.254",
            ipv4PrimaryServiceIdentity: "service-a",
            ipv6PrimaryServiceIdentity: "service-v6"
        )

        #expect(first != changedAddress)
        #expect(first != changedRoute)
    }

    @Test("fingerprint comparison ignores address and tunnel collection order")
    func fingerprintNormalizesUnorderedCollections() {
        let first = NetworkFingerprint(
            interfaceType: "ethernet",
            interfaceName: "en7",
            pathStatus: .satisfied,
            dnsSettingsHash: 1,
            staticProxySettingsHash: 7,
            tunnelInterfaces: ["utun3", "utun2"],
            selectedInterfaceAddresses: ["192.0.2.11", "192.0.2.10"],
            selectedInterfaceSubnets: ["255.255.255.0", "255.255.0.0"]
        )
        let reordered = NetworkFingerprint(
            interfaceType: "ethernet",
            interfaceName: "en7",
            pathStatus: .satisfied,
            dnsSettingsHash: 1,
            staticProxySettingsHash: 7,
            tunnelInterfaces: ["utun2", "utun3"],
            selectedInterfaceAddresses: ["192.0.2.10", "192.0.2.11"],
            selectedInterfaceSubnets: ["255.255.0.0", "255.255.255.0"]
        )

        #expect(first == reordered)
        #expect(first.restartReason(comparedWith: reordered) == .path)
    }

    private func makeResults(
        path: NetworkDiagnosticStatus,
        gateway: NetworkDiagnosticStatus = .normal,
        dns: NetworkDiagnosticStatus,
        internet: NetworkDiagnosticStatus,
        ipv6: NetworkDiagnosticStatus = .skipped,
        proxy: NetworkDiagnosticStatus
    ) -> [NetworkDiagnosticResult] {
        [
            NetworkDiagnosticResult(id: .path, status: path, summary: "path"),
            NetworkDiagnosticResult(id: .gatewayReachability, status: gateway, summary: "gateway"),
            NetworkDiagnosticResult(id: .dns, status: dns, summary: "dns"),
            NetworkDiagnosticResult(id: .internet, status: internet, summary: "internet"),
            NetworkDiagnosticResult(id: .ipv6, status: ipv6, summary: "ipv6"),
            NetworkDiagnosticResult(id: .proxy, status: proxy, summary: "proxy"),
        ]
    }

    private func makeFingerprint(
        interfaceName: String,
        dnsHash: UInt64
    ) -> NetworkFingerprint {
        NetworkFingerprint(
            interfaceType: "wifi",
            interfaceName: interfaceName,
            pathStatus: .satisfied,
            dnsSettingsHash: dnsHash,
            staticProxySettingsHash: 7
        )
    }

    private func makeStubChecks(recorder: DiagnosticTestRecorder) -> [any DiagnosticCheck] {
        [.path, .dns, .proxy].map { id in
            StubDiagnosticCheck(
                id: id,
                result: NetworkDiagnosticResult(id: id, status: .normal, summary: id.rawValue),
                recorder: recorder
            )
        }
    }
}

private struct AppLocalNetworkUsageDescription {
    let target: String
    let configuration: String
    let baseConfiguration: String
    let value: String
}

private func appLocalNetworkUsageDescriptions() throws -> [AppLocalNetworkUsageDescription] {
    let projectURL = try privacyCopyProjectURL()
    let project = try String(contentsOf: projectURL, encoding: .utf8)
    return try appLocalNetworkUsageDescriptions(from: project)
}

private func appLocalNetworkUsageDescriptions(
    from project: String
) throws -> [AppLocalNetworkUsageDescription] {
    let settingPrefix = "INFOPLIST_KEY_NSLocalNetworkUsageDescription = \""
    let selectedTargets = ["WiFiLens", "WiFiLensPro"]

    return try selectedTargets.flatMap { targetName in
        let target = try nativeTarget(named: targetName, in: project)
        guard target.contains("productType = \"com.apple.product-type.application\";") else {
            throw projectConfigurationError("\(targetName) is not an application target.")
        }
        let configurationListID = try pbxIdentifier(
            after: "buildConfigurationList = ",
            in: target,
            context: "\(targetName) target"
        )
        let configurationList = try pbxObject(
            id: configurationListID,
            in: project,
            context: "\(targetName) configuration list"
        )
        guard configurationList.contains("isa = XCConfigurationList;") else {
            throw projectConfigurationError("\(configurationListID) is not an XCConfigurationList.")
        }

        let configurationIDs = try buildConfigurationIDs(in: configurationList)
        let configurations = try configurationIDs.map { configurationID in
            let configuration = try pbxObject(
                id: configurationID,
                in: project,
                context: "\(targetName) build configuration"
            )
            guard configuration.contains("isa = XCBuildConfiguration;") else {
                throw projectConfigurationError("\(configurationID) is not an XCBuildConfiguration.")
            }
            let name = try pbxValue(
                after: "name = ",
                in: configuration,
                context: "\(configurationID) name"
            )
            let baseConfiguration = try requiredMatch(
                ["OSS.xcconfig", "PRO.xcconfig"],
                in: configuration,
                context: "\(configurationID) base configuration"
            )
            let settingRange = try requiredRange(
                of: settingPrefix,
                in: configuration,
                context: "\(configurationID) local-network privacy copy"
            )
            let valueStart = settingRange.upperBound
            let valueEnd = try requiredIndex(
                of: "\"",
                in: configuration[valueStart...],
                context: "\(configurationID) local-network privacy copy closing quote"
            )
            return AppLocalNetworkUsageDescription(
                target: targetName,
                configuration: name,
                baseConfiguration: baseConfiguration,
                value: String(configuration[valueStart..<valueEnd])
            )
        }

        guard configurations.count == 2,
              Set(configurations.map(\.configuration)) == ["Debug", "Release"] else {
            throw projectConfigurationError("\(targetName) must provide exactly Debug and Release configurations.")
        }
        return configurations
    }
}

private func nativeTarget(named name: String, in project: String) throws -> String {
    let marker = " /* \(name) */ = {\n\t\t\tisa = PBXNativeTarget;"
    let markerRange = try requiredRange(of: marker, in: project, context: "\(name) PBXNativeTarget")
    let lineStart = project[..<markerRange.lowerBound].lastIndex(of: "\n")
        .map { project.index(after: $0) }
        ?? project.startIndex
    let identifier = String(project[lineStart..<markerRange.lowerBound])
        .trimmingCharacters(in: .whitespacesAndNewlines)
    return try pbxObject(id: identifier, in: project, context: "\(name) PBXNativeTarget")
}

private func pbxObject(id: String, in project: String, context: String) throws -> String {
    let header = "\t\t\(id) "
    let start: String.Index
    if project.hasPrefix(header) {
        start = project.startIndex
    } else {
        let headerRange = try requiredRange(of: "\n\(header)", in: project, context: context)
        start = project.index(after: headerRange.lowerBound)
    }
    let suffix = String(project[start...])
    let end = try requiredRange(
        of: "\n\t\t};",
        in: suffix,
        context: "\(context) closing brace"
    ).upperBound
    return String(suffix[..<end])
}

private func buildConfigurationIDs(in configurationList: String) throws -> [String] {
    let start = try requiredRange(
        of: "buildConfigurations = (",
        in: configurationList,
        context: "XCConfigurationList build configurations"
    ).upperBound
    let suffix = String(configurationList[start...])
    let end = try requiredRange(
        of: "\n\t\t\t);",
        in: suffix,
        context: "XCConfigurationList build configurations closing parenthesis"
    ).lowerBound
    return suffix[..<end]
        .split(separator: "\n")
        .compactMap { line in
            line.trimmingCharacters(in: .whitespaces).split(separator: " ").first.map(String.init)
        }
}

private func pbxIdentifier(after prefix: String, in object: String, context: String) throws -> String {
    let value = try pbxValue(after: prefix, in: object, context: context)
    guard !value.isEmpty else {
        throw projectConfigurationError("\(context) must name a PBX object identifier.")
    }
    return value
}

private func pbxValue(after prefix: String, in object: String, context: String) throws -> String {
    let valueStart = try requiredRange(of: prefix, in: object, context: context).upperBound
    let valueEnd = try requiredIndex(of: ";", in: object[valueStart...], context: "\(context) terminator")
    let value = object[valueStart..<valueEnd].trimmingCharacters(in: .whitespaces)
    return value.split(separator: " ").first.map(String.init) ?? ""
}

private func requiredMatch(_ candidates: [String], in value: String, context: String) throws -> String {
    guard let match = candidates.first(where: value.contains) else {
        throw projectConfigurationError("\(context) must reference OSS.xcconfig or PRO.xcconfig.")
    }
    return match
}

private func requiredRange(of needle: String, in value: String, context: String) throws -> Range<String.Index> {
    guard let range = value.range(of: needle) else {
        throw projectConfigurationError("Missing \(context).")
    }
    return range
}

private func requiredIndex(
    of character: Character,
    in value: Substring,
    context: String
) throws -> String.Index {
    guard let index = value.firstIndex(of: character) else {
        throw projectConfigurationError("Missing \(context).")
    }
    return index
}

private func projectConfigurationError(_ description: String) -> NSError {
    NSError(
        domain: "NetworkDiagnosticsTests",
        code: 1,
        userInfo: [NSLocalizedDescriptionKey: description]
    )
}

private func privacyCopyProjectURL() throws -> URL {
    var directory = URL(filePath: #filePath).deletingLastPathComponent()
    let marker = "WiFiLens/WiFiLens.xcodeproj/project.pbxproj"

    while directory.path != directory.deletingLastPathComponent().path {
        let candidate = directory.appending(path: marker)
        if FileManager.default.fileExists(atPath: candidate.path) {
            return candidate
        }
        directory = directory.deletingLastPathComponent()
    }

    throw NSError(
        domain: "NetworkDiagnosticsTests",
        code: 1,
        userInfo: [NSLocalizedDescriptionKey: "Could not locate \(marker) while searching ancestors of \(#filePath)."]
    )
}

private let privacyCopyProjectFixture = """
\t\tOSS_TARGET /* WiFiLens */ = {
\t\t\tisa = PBXNativeTarget;
\t\t\tbuildConfigurationList = OSS_LIST /* Build configuration list for PBXNativeTarget \"WiFiLens\" */;
\t\t\tname = WiFiLens;
\t\t\tproductType = \"com.apple.product-type.application\";
\t\t};
\t\tPRO_TARGET /* WiFiLensPro */ = {
\t\t\tisa = PBXNativeTarget;
\t\t\tbuildConfigurationList = PRO_LIST /* Build configuration list for PBXNativeTarget \"WiFiLensPro\" */;
\t\t\tname = WiFiLensPro;
\t\t\tproductType = \"com.apple.product-type.application\";
\t\t};
\t\tDECOY_TARGET /* OtherApp */ = {
\t\t\tisa = PBXNativeTarget;
\t\t\tbuildConfigurationList = DECOY_LIST /* Build configuration list for PBXNativeTarget \"OtherApp\" */;
\t\t\tname = OtherApp;
\t\t\tproductType = \"com.apple.product-type.application\";
\t\t};
\t\tOSS_LIST /* Build configuration list */ = {
\t\t\tisa = XCConfigurationList;
\t\t\tbuildConfigurations = (
\t\t\t\tOSS_DEBUG /* Debug */,
\t\t\t\tOSS_RELEASE /* Release */,
\t\t\t);
\t\t};
\t\tPRO_LIST /* Build configuration list */ = {
\t\t\tisa = XCConfigurationList;
\t\t\tbuildConfigurations = (
\t\t\t\tPRO_DEBUG /* Debug */,
\t\t\t\tPRO_RELEASE /* Release */,
\t\t\t);
\t\t};
\t\tDECOY_LIST /* Build configuration list */ = {
\t\t\tisa = XCConfigurationList;
\t\t\tbuildConfigurations = (
\t\t\t\tDECOY_DEBUG /* Debug */,
\t\t\t\tDECOY_RELEASE /* Release */,
\t\t\t);
\t\t};
\t\tOSS_DEBUG /* Debug */ = {
\t\t\tisa = XCBuildConfiguration;
\t\t\tbaseConfigurationReference = OSS_BASE /* OSS.xcconfig */;
\t\t\tbuildSettings = {
\t\t\t\tINFOPLIST_FILE = \"WiFiLens-Info.plist\";
\t\t\t\tINFOPLIST_KEY_NSLocalNetworkUsageDescription = \"expected app copy\";
\t\t\t};
\t\t\tname = Debug;
\t\t};
\t\tOSS_RELEASE /* Release */ = {
\t\t\tisa = XCBuildConfiguration;
\t\t\tbaseConfigurationReference = OSS_BASE /* OSS.xcconfig */;
\t\t\tbuildSettings = {
\t\t\t\tINFOPLIST_FILE = \"WiFiLens-Info.plist\";
\t\t\t\tINFOPLIST_KEY_NSLocalNetworkUsageDescription = \"expected app copy\";
\t\t\t};
\t\t\tname = Release;
\t\t};
\t\tPRO_DEBUG /* Debug */ = {
\t\t\tisa = XCBuildConfiguration;
\t\t\tbaseConfigurationReference = PRO_BASE /* PRO.xcconfig */;
\t\t\tbuildSettings = {
\t\t\t\tINFOPLIST_FILE = \"WiFiLensPro-Info.plist\";
\t\t\t\tINFOPLIST_KEY_NSLocalNetworkUsageDescription = \"expected app copy\";
\t\t\t};
\t\t\tname = Debug;
\t\t};
\t\tPRO_RELEASE /* Release */ = {
\t\t\tisa = XCBuildConfiguration;
\t\t\tbaseConfigurationReference = PRO_BASE /* PRO.xcconfig */;
\t\t\tbuildSettings = {
\t\t\t\tINFOPLIST_FILE = \"WiFiLensPro-Info.plist\";
\t\t\t\tINFOPLIST_KEY_NSLocalNetworkUsageDescription = \"expected app copy\";
\t\t\t};
\t\t\tname = Release;
\t\t};
\t\tDECOY_DEBUG /* Debug */ = {
\t\t\tisa = XCBuildConfiguration;
\t\t\tbaseConfigurationReference = DECOY_BASE /* OSS.xcconfig */;
\t\t\tbuildSettings = {
\t\t\t\tINFOPLIST_FILE = \"Other-Info.plist\";
\t\t\t\tINFOPLIST_KEY_NSLocalNetworkUsageDescription = \"decoy copy\";
\t\t\t};
\t\t\tname = Debug;
\t\t};
\t\tDECOY_RELEASE /* Release */ = {
\t\t\tisa = XCBuildConfiguration;
\t\t\tbaseConfigurationReference = DECOY_BASE /* OSS.xcconfig */;
\t\t\tbuildSettings = {
\t\t\t\tINFOPLIST_FILE = \"Other-Info.plist\";
\t\t\t\tINFOPLIST_KEY_NSLocalNetworkUsageDescription = \"decoy copy\";
\t\t\t};
\t\t\tname = Release;
\t\t};
"""

private struct StubPathSource: NetworkPathChecking {
    let state: NetworkPathState?

    init(_ state: NetworkPathState?) {
        self.state = state
    }

    func currentState(timeout: Duration) async -> NetworkPathState? {
        state
    }
}

private actor ConcurrentDNSResolver: DNSResolving {
    private(set) var maximumInFlight = 0
    private var inFlight = 0

    func resolve(host: String, timeout: Duration) async -> DNSResolutionOutcome {
        inFlight += 1
        maximumInFlight = max(maximumInFlight, inFlight)
        try? await Task.sleep(for: .milliseconds(20))
        inFlight -= 1
        return .resolved
    }
}

private actor ConcurrentControlLoader: ControlEndpointLoading {
    private(set) var maximumInFlight = 0
    private var inFlight = 0

    func load(url: URL, timeout: Duration) async -> ControlEndpointLoadResult {
        inFlight += 1
        maximumInFlight = max(maximumInFlight, inFlight)
        try? await Task.sleep(for: .milliseconds(20))
        inFlight -= 1
        if url.host == "captive.apple.com" {
            return .init(status: 200, body: "Success", errorCode: nil)
        }
        return .init(status: 200, body: nil, errorCode: nil)
    }
}

private struct MetricsControlLoader: ControlEndpointLoading {
    let metrics: ControlEndpointMetrics

    func load(url: URL, timeout: Duration) async -> ControlEndpointLoadResult {
        if url.host == "captive.apple.com" {
            return .init(status: 200, body: "Success", errorCode: nil)
        }
        return .init(status: 200, body: nil, errorCode: nil, metrics: metrics)
    }
}

private actor BudgetAwareDiagnosticProbe {
    private(set) var wasCancelled = false

    func run() async {
        do {
            try await Task.sleep(for: .seconds(30))
        } catch {
            wasCancelled = true
        }
    }
}

private actor ManualDiagnosticClock: DiagnosticClock {
    let origin: ContinuousClock.Instant
    private var current: ContinuousClock.Instant
    private var sleepers: [UUID: (deadline: ContinuousClock.Instant, continuation: CheckedContinuation<Void, Never>)] = [:]

    init(origin: ContinuousClock.Instant = ContinuousClock.now) {
        self.origin = origin
        current = origin
    }

    func now() async -> ContinuousClock.Instant {
        current
    }

    func sleep(until deadline: ContinuousClock.Instant) async throws {
        try Task.checkCancellation()
        guard current < deadline else { return }
        let sleeperID = UUID()
        await withTaskCancellationHandler {
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                if current >= deadline || Task.isCancelled {
                    continuation.resume()
                } else {
                    sleepers[sleeperID] = (deadline, continuation)
                }
            }
        } onCancel: {
            Task { await self.cancelSleep(id: sleeperID) }
        }
        try Task.checkCancellation()
    }

    func set(_ value: ContinuousClock.Instant) {
        current = value
        let readyIDs = sleepers.compactMap { id, sleeper in
            sleeper.deadline <= value ? id : nil
        }
        let readySleepers = readyIDs.compactMap { sleepers.removeValue(forKey: $0) }
        for sleeper in readySleepers {
            sleeper.continuation.resume()
        }
    }

    private func cancelSleep(id: UUID) {
        guard let sleeper = sleepers.removeValue(forKey: id) else { return }
        sleeper.continuation.resume()
    }
}

private struct BudgetAwareDiagnosticCheck: DiagnosticCheck {
    let id: NetworkDiagnosticCheckID = .path
    let probe: BudgetAwareDiagnosticProbe

    func run() async throws -> NetworkDiagnosticResult {
        try await probe.run()
        return .init(id: id, status: .normal, summary: id.rawValue)
    }
}

private actor StubDNSResolver: DNSResolving {
    private var outcomes: [DNSResolutionOutcome]
    private var outcomeIndex = 0
    private(set) var invocationCount = 0

    init(_ outcome: DNSResolutionOutcome) {
        outcomes = [outcome]
    }

    init(outcomes: [DNSResolutionOutcome]) {
        precondition(!outcomes.isEmpty)
        self.outcomes = outcomes
    }

    func resolve(host: String, timeout: Duration) async -> DNSResolutionOutcome {
        invocationCount += 1
        defer { outcomeIndex += 1 }
        return outcomes[min(outcomeIndex, outcomes.endIndex - 1)]
    }
}

private struct MappingDNSResolver: DNSResolving {
    let outcomes: [String: DNSResolutionOutcome]

    func resolve(host: String, timeout: Duration) async -> DNSResolutionOutcome {
        outcomes[host] ?? .indeterminate
    }
}

private actor CancellationAwareDNSResolver: DNSResolving {
    private var invocationWaiter: CheckedContinuation<Void, Never>?
    private(set) var invocationCount = 0

    func resolve(host: String, timeout: Duration) async -> DNSResolutionOutcome {
        invocationCount += 1
        invocationWaiter?.resume()
        invocationWaiter = nil
        try? await Task.sleep(for: timeout)
        return .indeterminate
    }

    func waitForInvocation() async {
        guard invocationCount == 0 else { return }
        await withCheckedContinuation { invocationWaiter = $0 }
    }
}

private struct StubControlLoader: ControlEndpointLoading {
    let httpsStatus: Int?
    let httpsErrorCode: String?
    let httpStatus: Int?
    let httpBody: String?
    let httpErrorCode: String?
    let recorder: ControlEndpointTestRecorder?

    init(
        httpsStatus: Int?,
        httpsErrorCode: String? = nil,
        httpStatus: Int?,
        httpBody: String?,
        httpErrorCode: String? = nil,
        recorder: ControlEndpointTestRecorder? = nil
    ) {
        self.httpsStatus = httpsStatus
        self.httpsErrorCode = httpsErrorCode
        self.httpStatus = httpStatus
        self.httpBody = httpBody
        self.httpErrorCode = httpErrorCode
        self.recorder = recorder
    }

    func load(url: URL, timeout: Duration) async -> ControlEndpointLoadResult {
        await recorder?.record(url: url, timeout: timeout)
        if url.host == "captive.apple.com" {
            return .init(status: httpStatus, body: httpBody, errorCode: httpErrorCode)
        }
        return .init(status: httpsStatus, body: nil, errorCode: httpsErrorCode)
    }
}

private struct StubIPv6Loader: IPv6ControlEndpointLoading {
    let outcome: IPv6ControlEndpointLoadOutcome

    init(_ outcome: IPv6ControlEndpointLoadOutcome) {
        self.outcome = outcome
    }

    func load(url: URL, timeout: Duration) async -> IPv6ControlEndpointLoadOutcome {
        outcome
    }
}

private struct StubGlobalIPv6AddressSource: GlobalIPv6AddressSourcing {
    let hasAddress: Bool

    func hasGlobalIPv6Address() -> Bool {
        hasAddress
    }
}

private struct StubIPv6AddressResolver: IPv6AddressResolving {
    let addresses: [String]

    func resolveAAAA(host: String, timeout: Duration) async -> [String] {
        addresses
    }
}

private actor RecordingIPv6AddressResolver: IPv6AddressResolving {
    let addresses: [String]
    private(set) var hosts: [String] = []

    init(addresses: [String]) {
        self.addresses = addresses
    }

    func resolveAAAA(host: String, timeout: Duration) async -> [String] {
        hosts.append(host)
        return addresses
    }
}

private struct IPv6LoaderTestRequest: Equatable, Sendable {
    let url: URL
    let ipv6Address: String
    let serverName: String
    let timeout: Duration
}

private actor IPv6LoaderTestRecorder {
    private(set) var requests: [IPv6LoaderTestRequest] = []

    func record(_ request: IPv6LoaderTestRequest) {
        requests.append(request)
    }
}

private struct RecordingIPv6HTTPSConnector: IPv6HTTPSConnecting {
    let succeeds: Bool
    let recorder: IPv6LoaderTestRecorder

    func load(
        url: URL,
        ipv6Address: String,
        serverName: String,
        timeout: Duration
    ) async -> Bool {
        await recorder.record(.init(
            url: url,
            ipv6Address: ipv6Address,
            serverName: serverName,
            timeout: timeout
        ))
        return succeeds
    }
}

private struct StubIPv6HTTPSConnector: IPv6HTTPSConnecting {
    let succeeds: Bool

    func load(
        url: URL,
        ipv6Address: String,
        serverName: String,
        timeout: Duration
    ) async -> Bool {
        succeeds
    }
}

private actor SequencedIPv6HTTPSConnector: IPv6HTTPSConnecting {
    let successfulAddress: String
    private(set) var addresses: [String] = []
    private(set) var timeouts: [Duration] = []

    init(successfulAddress: String) {
        self.successfulAddress = successfulAddress
    }

    func load(
        url: URL,
        ipv6Address: String,
        serverName: String,
        timeout: Duration
    ) async -> Bool {
        addresses.append(ipv6Address)
        timeouts.append(timeout)
        return ipv6Address == successfulAddress
    }
}

private actor ControlEndpointTestRecorder {
    private(set) var urls: [String] = []
    private(set) var timeouts: [Duration] = []

    func record(url: URL, timeout: Duration) {
        urls.append(url.absoluteString)
        timeouts.append(timeout)
    }
}

private struct StubProxyConfigurationResolver: ProxyConfigurationResolving {
    let storedResolutions: [ProxyResolutionDirective]

    init(_ resolution: ProxyResolutionDirective) {
        storedResolutions = [resolution]
    }

    init(_ resolutions: [ProxyResolutionDirective]) {
        storedResolutions = resolutions
    }

    func resolutions(for url: URL) -> [ProxyResolutionDirective] {
        storedResolutions
    }
}

private struct PACResolutionTestRequest: Equatable, Sendable {
    let pacURL: URL
    let targetURL: URL
    let timeout: Duration
}

private actor PACResolutionTestRecorder {
    private(set) var requests: [PACResolutionTestRequest] = []

    func record(pacURL: URL, targetURL: URL, timeout: Duration) {
        requests.append(.init(pacURL: pacURL, targetURL: targetURL, timeout: timeout))
    }
}

private struct PACCallbackTestRequest: Equatable, Sendable {
    let source: PACSource
    let targetURL: URL
}

private final class ControlledPACCallbackExecution: PACCallbackExecution, @unchecked Sendable {
    private let lock = NSLock()
    private var cancelled = false

    var isCancelled: Bool {
        lock.withLock { cancelled }
    }

    func cancel() {
        lock.withLock { cancelled = true }
    }
}

private final class ControlledPACCallbackExecutor: PACCallbackExecuting, @unchecked Sendable {
    private let lock = NSLock()
    private let requestStream: AsyncStream<PACCallbackTestRequest>
    private let requestContinuation: AsyncStream<PACCallbackTestRequest>.Continuation
    private var callback: (@Sendable (PACCallbackOutcome) -> Void)?
    private var execution: ControlledPACCallbackExecution?

    init() {
        let pair = AsyncStream<PACCallbackTestRequest>.makeStream()
        requestStream = pair.stream
        requestContinuation = pair.continuation
    }

    var executionWasCancelled: Bool {
        lock.withLock { execution?.isCancelled == true }
    }

    func execute(
        source: PACSource,
        targetURL: URL,
        callback: @escaping @Sendable (PACCallbackOutcome) -> Void
    ) -> any PACCallbackExecution {
        let execution = ControlledPACCallbackExecution()
        lock.withLock {
            self.callback = callback
            self.execution = execution
        }
        requestContinuation.yield(.init(source: source, targetURL: targetURL))
        return execution
    }

    func nextRequest() async -> PACCallbackTestRequest? {
        for await request in requestStream {
            return request
        }
        return nil
    }

    func complete(_ outcome: PACCallbackOutcome) {
        let callback = lock.withLock {
            let callback = self.callback
            self.callback = nil
            return callback
        }
        callback?(outcome)
    }
}

private struct StubPACResolver: PACResolving {
    let resolution: ProxyCandidateResolution
    let recorder: PACResolutionTestRecorder?

    init(_ resolution: EffectiveProxy, recorder: PACResolutionTestRecorder? = nil) {
        switch resolution {
        case .unavailable(let reason):
            self.resolution = ProxyCandidateResolution(candidates: [], evidenceCodes: [reason])
        default:
            self.resolution = ProxyCandidateResolution(candidates: [resolution], evidenceCodes: [])
        }
        self.recorder = recorder
    }

    init(_ resolution: ProxyCandidateResolution, recorder: PACResolutionTestRecorder? = nil) {
        self.resolution = resolution
        self.recorder = recorder
    }

    func resolve(
        pacURL: URL,
        targetURL: URL,
        timeout: Duration
    ) async -> ProxyCandidateResolution {
        await recorder?.record(pacURL: pacURL, targetURL: targetURL, timeout: timeout)
        return resolution
    }
}

private actor CancellationIgnoringPACResolver: PACResolving {
    private var invocationWaiters: [CheckedContinuation<Void, Never>] = []
    private var hasInvoked = false

    func resolve(
        pacURL: URL,
        targetURL: URL,
        timeout: Duration
    ) async -> ProxyCandidateResolution {
        hasInvoked = true
        invocationWaiters.forEach { $0.resume() }
        invocationWaiters = []
        try? await Task.sleep(for: .seconds(30))
        return ProxyCandidateResolution(candidates: [], evidenceCodes: ["pac-cancelled"])
    }

    func waitForInvocation() async {
        guard !hasInvoked else { return }
        await withCheckedContinuation { invocationWaiters.append($0) }
    }
}

private struct StubProxyResolver: ProxyResolving {
    let resolution: ProxyCandidateResolution

    init(_ resolution: EffectiveProxy) {
        switch resolution {
        case .unavailable(let reason):
            self.resolution = ProxyCandidateResolution(candidates: [], evidenceCodes: [reason])
        default:
            self.resolution = ProxyCandidateResolution(candidates: [resolution], evidenceCodes: [])
        }
    }

    init(_ resolution: ProxyCandidateResolution) {
        self.resolution = resolution
    }

    func resolve(for url: URL) async -> ProxyCandidateResolution {
        resolution
    }
}

private struct StubProxyTunnelStateReader: ProxyTunnelStateReading {
    let state: ProxyTunnelState?

    init(
        interface: String?,
        source: ProxyTunnelDetectionSource = .nwpath
    ) {
        self.state = interface.map {
            ProxyTunnelState(interface: $0, source: source)
        }
    }

    func tunnelState() async -> ProxyTunnelState? {
        state
    }
}

private final class TunnelTimeoutCancellationProbe: @unchecked Sendable {
    private let lock = NSLock()
    private var parkedContinuation: CheckedContinuation<Void, Never>?
    private var cancelled = false

    var didCancel: Bool {
        lock.lock()
        defer { lock.unlock() }
        return cancelled
    }

    func park() async {
        await withTaskCancellationHandler {
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                lock.lock()
                if cancelled {
                    lock.unlock()
                    continuation.resume()
                } else {
                    parkedContinuation = continuation
                    lock.unlock()
                }
            }
        } onCancel: {
            lock.lock()
            cancelled = true
            parkedContinuation?.resume()
            parkedContinuation = nil
            lock.unlock()
        }
    }
}

private final class LockedFlag: @unchecked Sendable {
    private let lock = NSLock()
    private var value = false

    var isSet: Bool {
        lock.lock()
        defer { lock.unlock() }
        return value
    }

    func set() {
        lock.lock()
        value = true
        lock.unlock()
    }
}

private actor ProxyResolutionTestRecorder {
    private(set) var urls: [String] = []

    func record(_ url: URL) {
        urls.append(url.absoluteString)
    }
}

private struct RecordingProxyResolver: ProxyResolving {
    let resolutions: [URL: ProxyCandidateResolution]
    let defaultResolution: ProxyCandidateResolution?
    let recorder: ProxyResolutionTestRecorder?

    init(
        resolutions: [URL: ProxyCandidateResolution],
        recorder: ProxyResolutionTestRecorder? = nil
    ) {
        self.resolutions = resolutions
        defaultResolution = nil
        self.recorder = recorder
    }

    init(
        defaultResolution: ProxyCandidateResolution,
        recorder: ProxyResolutionTestRecorder? = nil
    ) {
        resolutions = [:]
        self.defaultResolution = defaultResolution
        self.recorder = recorder
    }

    func resolve(for url: URL) async -> ProxyCandidateResolution {
        await recorder?.record(url)
        return resolutions[url]
            ?? defaultResolution
            ?? ProxyCandidateResolution(candidates: [], evidenceCodes: ["fixture-missing"])
    }
}

private actor CancellationIgnoringProxyResolver: ProxyResolving {
    private(set) var urls: [String] = []
    private var invocationWaiters: [CheckedContinuation<Void, Never>] = []

    func resolve(for url: URL) async -> ProxyCandidateResolution {
        urls.append(url.absoluteString)
        if urls.count == 1 {
            invocationWaiters.forEach { $0.resume() }
            invocationWaiters = []
            try? await Task.sleep(for: .seconds(30))
        }
        return ProxyCandidateResolution(candidates: [.direct], evidenceCodes: [])
    }

    func waitForInvocation() async {
        guard urls.isEmpty else { return }
        await withCheckedContinuation { invocationWaiters.append($0) }
    }
}

private func proxyDictionary(
    type: CFString,
    host: String? = nil,
    port: Int? = nil
) -> NSDictionary {
    let dictionary = NSMutableDictionary()
    dictionary[kCFProxyTypeKey] = type
    if let host { dictionary[kCFProxyHostNameKey] = host }
    if let port { dictionary[kCFProxyPortNumberKey] = NSNumber(value: port) }
    return dictionary
}

private struct ProxyEgressTestRequest: Equatable, Sendable {
    let url: URL
    let proxy: EffectiveProxy
}

private actor ProxyEgressTestRecorder {
    private(set) var requests: [ProxyEgressTestRequest] = []

    func record(url: URL, proxy: EffectiveProxy) {
        requests.append(.init(url: url, proxy: proxy))
    }
}

private struct StubProxyEgressLoader: ProxyEgressLoading {
    let statusCode: Int?
    let errorCode: String?
    let recorder: ProxyEgressTestRecorder?

    init(
        statusCode: Int?,
        errorCode: String? = nil,
        recorder: ProxyEgressTestRecorder? = nil
    ) {
        self.statusCode = statusCode
        self.errorCode = errorCode
        self.recorder = recorder
    }

    func load(
        url: URL,
        through proxy: EffectiveProxy,
        timeout: Duration
    ) async -> ProxyEgressResponse {
        await recorder?.record(url: url, proxy: proxy)
        return ProxyEgressResponse(statusCode: statusCode, errorCode: errorCode)
    }
}

private actor SequencedProxyEgressLoader: ProxyEgressLoading {
    let responses: [ProxyEgressResponse]
    let delays: [Duration]
    private(set) var timeouts: [Duration] = []
    private var invocationCount = 0

    init(responses: [ProxyEgressResponse], delays: [Duration]) {
        self.responses = responses
        self.delays = delays
    }

    func load(
        url: URL,
        through proxy: EffectiveProxy,
        timeout: Duration
    ) async -> ProxyEgressResponse {
        let index = invocationCount
        invocationCount += 1
        timeouts.append(timeout)
        if delays.indices.contains(index) {
            try? await Task.sleep(for: delays[index])
        }
        guard responses.indices.contains(index) else {
            return ProxyEgressResponse(statusCode: nil, errorCode: "fixture-exhausted")
        }
        return responses[index]
    }
}

private final class SequencedProxyCheckClock: ProxyCheckClock, @unchecked Sendable {
    private let lock = NSLock()
    private let instants: [ContinuousClock.Instant]
    private var index = 0

    init(offsets: [Duration]) {
        let origin = ContinuousClock().now
        instants = offsets.map { origin.advanced(by: $0) }
    }

    func now() -> ContinuousClock.Instant {
        lock.lock()
        defer { lock.unlock() }
        precondition(index < instants.count, "Proxy test clock exhausted")
        defer { index += 1 }
        return instants[index]
    }
}

private actor CancellationIgnoringProxyEgressLoader: ProxyEgressLoading {
    private var invocationWaiters: [CheckedContinuation<Void, Never>] = []
    private(set) var invocationCount = 0

    func load(
        url: URL,
        through proxy: EffectiveProxy,
        timeout: Duration
    ) async -> ProxyEgressResponse {
        invocationCount += 1
        if invocationCount == 1 {
            invocationWaiters.forEach { $0.resume() }
            invocationWaiters = []
            try? await Task.sleep(for: .seconds(30))
        }
        return ProxyEgressResponse(statusCode: nil, errorCode: "cancelled-fixture")
    }

    func waitForInvocation() async {
        guard invocationCount == 0 else { return }
        await withCheckedContinuation { invocationWaiters.append($0) }
    }
}

private struct StubProxyConnector: ProxyEndpointConnecting {
    let reachable: Bool

    func canConnect(to endpoint: ProxyEndpoint, timeout: Duration) async -> Bool {
        reachable
    }
}

private struct EndpointSelectiveProxyConnector: ProxyEndpointConnecting {
    let reachableHosts: Set<String>

    func canConnect(to endpoint: ProxyEndpoint, timeout: Duration) async -> Bool {
        reachableHosts.contains(endpoint.host)
    }
}

private actor ProxyConnectorTestRecorder {
    private(set) var endpoints: [ProxyEndpoint] = []

    func record(_ endpoint: ProxyEndpoint) {
        endpoints.append(endpoint)
    }
}

private actor SequencedProxyConnector: ProxyEndpointConnecting {
    let outcomes: [Bool]
    private(set) var endpoints: [ProxyEndpoint] = []
    private(set) var timeouts: [Duration] = []
    private var invocationCount = 0

    init(outcomes: [Bool]) {
        self.outcomes = outcomes
    }

    func canConnect(to endpoint: ProxyEndpoint, timeout: Duration) async -> Bool {
        let index = invocationCount
        invocationCount += 1
        endpoints.append(endpoint)
        timeouts.append(timeout)
        return outcomes.indices.contains(index) ? outcomes[index] : false
    }
}

private actor CancellationIgnoringProxyConnector: ProxyEndpointConnecting {
    private var invocationWaiters: [CheckedContinuation<Void, Never>] = []
    private(set) var endpoints: [ProxyEndpoint] = []

    func canConnect(to endpoint: ProxyEndpoint, timeout: Duration) async -> Bool {
        endpoints.append(endpoint)
        if endpoints.count == 1 {
            invocationWaiters.forEach { $0.resume() }
            invocationWaiters = []
            try? await Task.sleep(for: .seconds(30))
        }
        return false
    }

    func waitForInvocation() async {
        guard endpoints.isEmpty else { return }
        await withCheckedContinuation { invocationWaiters.append($0) }
    }
}

private struct RecordingProxyConnector: ProxyEndpointConnecting {
    let reachable: Bool
    let recorder: ProxyConnectorTestRecorder

    func canConnect(to endpoint: ProxyEndpoint, timeout: Duration) async -> Bool {
        await recorder.record(endpoint)
        return reachable
    }
}

private actor DiagnosticTestRecorder {
    private(set) var values: [NetworkDiagnosticCheckID] = []

    func record(_ value: NetworkDiagnosticCheckID) {
        values.append(value)
    }
}

/// Isolated guidance harness: in-memory store, fixed clock, collecting event
/// sink. Keeps diagnostics view-model tests hermetic (no real UserDefaults,
/// no Launch Services queries).
@MainActor
private final class IsolatedGuidance {
    let store: InMemoryGuidanceStateStore
    let coordinator: GuidanceCoordinator
    private let eventBox: EventBox

    var events: [GuidanceEvent] { eventBox.events }

    init(completionCount: Int = 0) {
        let calendar = Self.makeCalendar()
        let now = calendar.date(from: DateComponents(year: 2026, month: 8, day: 5, hour: 12))!
        let box = EventBox()
        store = InMemoryGuidanceStateStore(initial: GuidanceState(
            activeDays: ["2026-07-01", "2026-07-02"],
            meaningfulCompletionCount: completionCount
        ))
        var configuration = GuidanceConfiguration()
        configuration.invitationEnabled = true
        coordinator = GuidanceCoordinator(
            configuration: configuration,
            stateStore: store,
            now: { now },
            calendar: calendar,
            appVersion: { "2.1.0" },
            isProAppInstalled: { false },
            eventSink: { event in
                box.events.append(event)
            }
        )
        eventBox = box
    }

    private static func makeCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }
}

@MainActor
private final class EventBox {
    var events: [GuidanceEvent] = []
}

private struct StubDiagnosticCheck: DiagnosticCheck {
    let id: NetworkDiagnosticCheckID
    let result: NetworkDiagnosticResult
    let recorder: DiagnosticTestRecorder

    func run() async -> NetworkDiagnosticResult {
        await recorder.record(id)
        return result
    }
}

private actor RestartableDiagnosticProbe {
    private let blockFirstInvocation: Bool
    private var firstInvocationContinuation: CheckedContinuation<Void, Never>?
    private var invocationWaiters: [(count: Int, continuation: CheckedContinuation<Void, Never>)] = []
    private(set) var invocationCount = 0

    init(blockFirstInvocation: Bool = false) {
        self.blockFirstInvocation = blockFirstInvocation
    }

    func run() async {
        invocationCount += 1
        let completedCount = invocationCount
        let readyWaiters = invocationWaiters.filter { $0.count <= completedCount }
        invocationWaiters.removeAll { $0.count <= completedCount }
        for waiter in readyWaiters {
            waiter.continuation.resume()
        }

        guard blockFirstInvocation, completedCount == 1 else { return }
        await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                firstInvocationContinuation = continuation
            }
        } onCancel: {
            Task { await self.releaseFirstInvocation() }
        }
    }

    func waitForInvocationCount(_ expectedCount: Int) async {
        guard invocationCount < expectedCount else { return }
        await withCheckedContinuation { continuation in
            invocationWaiters.append((expectedCount, continuation))
        }
    }

    func releaseFirstInvocation() {
        firstInvocationContinuation?.resume()
        firstInvocationContinuation = nil
    }
}

private struct ProbeDiagnosticCheck: DiagnosticCheck {
    let id: NetworkDiagnosticCheckID
    let result: NetworkDiagnosticResult
    let rerunPolicy: DiagnosticCheckRerunPolicy
    let probe: RestartableDiagnosticProbe

    func run() async -> NetworkDiagnosticResult {
        await probe.run()
        return result
    }
}

private actor BlockingDiagnosticProbe {
    private var continuations: [Int: CheckedContinuation<Void, Never>] = [:]
    private var invocationWaiters: [(count: Int, continuation: CheckedContinuation<Void, Never>)] = []
    private(set) var invocationCount = 0

    func run() async {
        invocationCount += 1
        let invocation = invocationCount
        let readyWaiters = invocationWaiters.filter { $0.count <= invocation }
        invocationWaiters.removeAll { $0.count <= invocation }
        readyWaiters.forEach { $0.continuation.resume() }

        await withTaskCancellationHandler {
            await withCheckedContinuation { continuations[invocation] = $0 }
        } onCancel: {
            Task { await self.release(invocation: invocation) }
        }
    }

    func waitForInvocationCount(_ expectedCount: Int) async {
        guard invocationCount < expectedCount else { return }
        await withCheckedContinuation {
            invocationWaiters.append((expectedCount, $0))
        }
    }

    func release(invocation: Int) {
        continuations.removeValue(forKey: invocation)?.resume()
    }
}

private struct BlockingProbeDiagnosticCheck: DiagnosticCheck {
    let id: NetworkDiagnosticCheckID
    let probe: BlockingDiagnosticProbe

    func run() async -> NetworkDiagnosticResult {
        await probe.run()
        return .init(id: id, status: .normal, summary: id.rawValue)
    }
}

private actor CancellationIgnoringDiagnosticProbe {
    private var continuations: [Int: CheckedContinuation<Void, Never>] = [:]
    private var invocationWaiters: [(count: Int, continuation: CheckedContinuation<Void, Never>)] = []
    private(set) var invocationCount = 0

    func run() async {
        invocationCount += 1
        let invocation = invocationCount
        let readyWaiters = invocationWaiters.filter { $0.count <= invocation }
        invocationWaiters.removeAll { $0.count <= invocation }
        readyWaiters.forEach { $0.continuation.resume() }

        await withCheckedContinuation { continuation in
            continuations[invocation] = continuation
        }
    }

    func waitForInvocationCount(_ expectedCount: Int) async {
        guard invocationCount < expectedCount else { return }
        await withCheckedContinuation {
            invocationWaiters.append((expectedCount, $0))
        }
    }

    func release(invocation: Int) {
        continuations.removeValue(forKey: invocation)?.resume()
    }
}

private struct CancellationIgnoringProbeDiagnosticCheck: DiagnosticCheck {
    let id: NetworkDiagnosticCheckID = .path
    let probe: CancellationIgnoringDiagnosticProbe

    func run() async -> NetworkDiagnosticResult {
        await probe.run()
        return .init(id: id, status: .normal, summary: id.rawValue)
    }
}

private actor ControlledNetworkFingerprintMonitor: NetworkFingerprintMonitoring {
    let initial: NetworkFingerprint
    private var lastFingerprint: NetworkFingerprint
    private var continuation: AsyncStream<NetworkFingerprint>.Continuation?
    private var pending: [NetworkFingerprint] = []

    init(initial: NetworkFingerprint) {
        self.initial = initial
        self.lastFingerprint = initial
    }

    func observation() async -> NetworkFingerprintObservation? {
        let pair = AsyncStream<NetworkFingerprint>.makeStream()
        install(pair.continuation)
        return NetworkFingerprintObservation(baseline: initial, changes: pair.stream)
    }

    func send(_ fingerprint: NetworkFingerprint) {
        guard fingerprint != lastFingerprint else { return }
        lastFingerprint = fingerprint
        guard let continuation else {
            pending.append(fingerprint)
            return
        }
        continuation.yield(fingerprint)
    }

    private func install(_ continuation: AsyncStream<NetworkFingerprint>.Continuation) {
        self.continuation = continuation
        for fingerprint in pending {
            continuation.yield(fingerprint)
        }
        pending = []
    }
}

private struct SilentNetworkPathFingerprintSource: NetworkPathFingerprintSourcing {
    func pathFingerprintChanges() -> AsyncStream<NetworkPathFingerprint> {
        AsyncStream { $0.finish() }
    }
}

private struct FiniteNetworkPathFingerprintSource: NetworkPathFingerprintSourcing {
    let values: [NetworkPathFingerprint]

    func pathFingerprintChanges() -> AsyncStream<NetworkPathFingerprint> {
        AsyncStream { continuation in
            values.forEach { continuation.yield($0) }
            continuation.finish()
        }
    }
}

private final class BufferedGapNetworkPathFingerprintSource: NetworkPathFingerprintSourcing, @unchecked Sendable {
    private let lock = NSLock()
    private let values: [NetworkPathFingerprint]
    private var requestCount = 0

    init(values: [NetworkPathFingerprint]) {
        self.values = values
    }

    var streamRequestCount: Int {
        lock.withLock { requestCount }
    }

    func pathFingerprintChanges() -> AsyncStream<NetworkPathFingerprint> {
        lock.withLock { requestCount += 1 }
        return AsyncStream { continuation in
            values.forEach { continuation.yield($0) }
            continuation.finish()
        }
    }
}

private struct ImmediateNetworkFingerprintSettingsPoller: NetworkFingerprintSettingsPolling {
    func ticks(every interval: Duration) -> AsyncStream<Void> {
        AsyncStream { continuation in
            continuation.yield(())
            continuation.finish()
        }
    }
}

private struct FixedCountNetworkFingerprintSettingsPoller: NetworkFingerprintSettingsPolling {
    let count: Int

    func ticks(every interval: Duration) -> AsyncStream<Void> {
        AsyncStream { continuation in
            for _ in 0..<count {
                continuation.yield(())
            }
            continuation.finish()
        }
    }
}

private struct SilentNetworkFingerprintSettingsPoller: NetworkFingerprintSettingsPolling {
    func ticks(every interval: Duration) -> AsyncStream<Void> {
        AsyncStream { $0.finish() }
    }
}

private final class MutableFingerprintSettingsReader: NetworkFingerprintSettingsReading, @unchecked Sendable {
    private let lock = NSLock()
    private var dnsHash: UInt64
    private let proxyHash: UInt64

    init(dnsHash: UInt64, proxyHash: UInt64) {
        self.dnsHash = dnsHash
        self.proxyHash = proxyHash
    }

    func dnsSettingsHash() -> UInt64 {
        lock.withLock { dnsHash }
    }

    func staticProxySettingsHash() -> UInt64 {
        proxyHash
    }

    func setDNSHash(_ value: UInt64) {
        lock.withLock { dnsHash = value }
    }
}

private actor SequencedFingerprintRouteStateSource: NetworkFingerprintRouteStateSourcing {
    private let values: [NetworkFingerprintRouteState]
    private var index = 0

    init(values: [NetworkFingerprintRouteState]) {
        precondition(!values.isEmpty)
        self.values = values
    }

    func currentState() async -> NetworkFingerprintRouteState? {
        defer { index += 1 }
        return values[min(index, values.endIndex - 1)]
    }
}

private final class SequencedFingerprintSettingsReader: NetworkFingerprintSettingsReading, @unchecked Sendable {
    private let lock = NSLock()
    private let dnsHashes: [UInt64]
    private let proxyHash: UInt64
    private var dnsIndex = 0

    init(dnsHashes: [UInt64], proxyHash: UInt64) {
        self.dnsHashes = dnsHashes
        self.proxyHash = proxyHash
    }

    func dnsSettingsHash() -> UInt64 {
        lock.withLock {
            guard !dnsHashes.isEmpty else { return 0 }
            let index = min(dnsIndex, dnsHashes.count - 1)
            dnsIndex += 1
            return dnsHashes[index]
        }
    }

    func staticProxySettingsHash() -> UInt64 {
        proxyHash
    }
}

private struct StubNetworkInterfaceSource: NetworkInterfaceInfoSourcing {
    let interface: NetworkInterfaceInfo?

    func currentInterface() async -> NetworkInterfaceInfo? {
        interface
    }
}

private actor RecordingGatewayPingProcessRunner: GatewayPingProcessRunning {
    let latency: Double?
    private(set) var executablePath: String?
    private(set) var arguments: [String] = []

    init(latency: Double?) {
        self.latency = latency
    }

    func run(executablePath: String, arguments: [String]) async -> Double? {
        self.executablePath = executablePath
        self.arguments = arguments
        return latency
    }

    func cancel() async {}
}

private actor RecordingDiagnosticGatewayMeasurer: DiagnosticGatewayMeasuring {
    private(set) var targets: [DiagnosticGatewayTarget] = []

    func measure(target: DiagnosticGatewayTarget) async -> GatewayLatencyResult {
        targets.append(target)
        return GatewayLatencyResult(
            timestamp: Date(),
            routerIP: target.address,
            latencyMs: 2.5
        )
    }
}

private actor SequencedDiagnosticRouteSource: DiagnosticRouteSourcing {
    private let values: [DiagnosticRouteSelection]
    private var index = 0
    private(set) var invocationCount = 0

    init(values: [DiagnosticRouteSelection]) {
        precondition(!values.isEmpty)
        self.values = values
    }

    func currentRoute(timeout: Duration) async -> DiagnosticRouteSelection {
        invocationCount += 1
        defer { index += 1 }
        return values[min(index, values.endIndex - 1)]
    }
}

private struct StubNetworkInterfaceSnapshotSource: NetworkInterfaceSnapshotSourcing {
    let interfaces: [NetworkInterfaceInfo]

    func capture(cycleID: UUID) async -> NetworkInterfaceSnapshot {
        NetworkInterfaceSnapshot(
            cycleID: cycleID,
            capturedAt: Date(),
            interfaces: interfaces
        )
    }
}

private struct StubGatewayLatencyProvider: GatewayLatencyProviding {
    let result: GatewayLatencyResult

    func measure(routerIP: String?) async -> GatewayLatencyResult {
        result
    }
}

private func makeNetworkInterface(name: String = "en0", router: String?) -> NetworkInterfaceInfo {
    NetworkInterfaceInfo(
        interfaceName: name,
        hardwareMAC: "00:11:22:33:44:55",
        ipv4Addresses: ["192.0.2.10"],
        subnetMasks: ["255.255.255.0"],
        router: router,
        dnsServers: ["192.0.2.53"],
        ssid: "Test Network",
        bssid: nil,
        channel: nil,
        band: nil,
        rssi: nil,
        txRate: nil,
        phyMode: nil,
        security: "WPA2"
    )
}

private func makeDiagnosticContext(
    pathState: NetworkPathState?,
    route: DiagnosticRouteSelection,
    interfaces: [NetworkInterfaceInfo] = []
) -> DiagnosticNetworkContext {
    DiagnosticNetworkContext(
        runID: UUID(),
        capturedAt: Date(),
        pathState: pathState,
        route: route,
        interfaces: NetworkInterfaceSnapshot(
            cycleID: UUID(),
            capturedAt: Date(),
            interfaces: interfaces
        )
    )
}
