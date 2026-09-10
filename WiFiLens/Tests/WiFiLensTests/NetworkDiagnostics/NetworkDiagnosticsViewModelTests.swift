import CFNetwork
import Foundation
import Network
import Testing
@testable import WiFi_Lens

extension NetworkDiagnosticsTests {
    @Test("view model starts idle and only runs after start")
    @MainActor
    func viewModelManualStart() async {
        let recorder = DiagnosticTestRecorder()
        let guidance = IsolatedGuidance()
        let viewModel = NetworkDiagnosticsViewModel(
            checks: makeStubChecks(recorder: recorder),
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

    @Test("fingerprint observation timeout does not wait for a cancellation-ignoring monitor")
    @MainActor
    func fingerprintObservationTimeoutIsBounded() async {
        let monitor = CancellationIgnoringNetworkFingerprintMonitor()
        let clock = ManualDiagnosticClock()
        let viewModel = NetworkDiagnosticsViewModel(
            checks: [],
            fingerprintMonitor: monitor,
            clock: clock
        )

        #expect(viewModel.start())
        await monitor.waitForInvocation()
        await clock.set(clock.origin.advanced(by: .seconds(1)))

        for _ in 0..<100 {
            if !viewModel.fingerprintMonitoringAvailable { break }
            await Task.yield()
        }

        #expect(!viewModel.fingerprintMonitoringAvailable)
        await monitor.release()
        await viewModel.waitForCompletion()
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

    @Test("stability window starts from the latest network change")
    func stabilityWindowUsesLatestChange() async {
        let controller = NetworkDiagnosticRestartController()
        let clock = ManualDiagnosticClock()
        let base = clock.origin
        let first = makeFingerprint(interfaceName: "en1", dnsHash: 2)
        let second = makeFingerprint(interfaceName: "en2", dnsHash: 3)
        let completion = OptionalBoolRecorder()

        #expect(await controller.observe(first, at: base))
        let waitTask = Task {
            let result = await controller.waitForStability(
                using: clock,
                until: base.advanced(by: .seconds(2))
            )
            await completion.record(result)
            return result
        }

        await clock.waitForSleeperCount(1)
        await clock.set(base.advanced(by: .milliseconds(400)))
        #expect(await controller.observe(
            second,
            at: base.advanced(by: .milliseconds(400))
        ))

        await clock.waitForSleeperCount(1)
        await clock.set(base.advanced(by: .milliseconds(800)))
        await Task.yield()
        #expect(await completion.value == nil)

        await clock.set(base.advanced(by: .milliseconds(900)))
        #expect(await waitTask.value)
        #expect(await completion.value == true)
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
}

