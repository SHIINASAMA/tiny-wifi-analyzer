import CFNetwork
import Foundation
import Network
import SystemConfiguration

struct NetworkFingerprint: Equatable, Sendable {
    let interfaceType: String?
    let interfaceName: String?
    let pathStatus: NetworkPathState
    let dnsSettingsHash: UInt64
    let staticProxySettingsHash: UInt64
    let tunnelInterfaces: [String]
    let routedTunnelInterface: String?

    init(
        interfaceType: String?,
        interfaceName: String?,
        pathStatus: NetworkPathState,
        dnsSettingsHash: UInt64,
        staticProxySettingsHash: UInt64,
        tunnelInterfaces: [String] = [],
        routedTunnelInterface: String? = nil
    ) {
        self.interfaceType = interfaceType
        self.interfaceName = interfaceName
        self.pathStatus = pathStatus
        self.dnsSettingsHash = dnsSettingsHash
        self.staticProxySettingsHash = staticProxySettingsHash
        self.tunnelInterfaces = tunnelInterfaces
        self.routedTunnelInterface = routedTunnelInterface
    }
}

struct NetworkFingerprintObservation: Sendable {
    let baseline: NetworkFingerprint
    let changes: AsyncStream<NetworkFingerprint>
}

protocol NetworkFingerprintMonitoring: Sendable {
    func observation() async -> NetworkFingerprintObservation?
}

struct DisabledNetworkFingerprintMonitor: NetworkFingerprintMonitoring {
    func observation() async -> NetworkFingerprintObservation? {
        nil
    }
}

protocol NetworkFingerprintSettingsReading: Sendable {
    func dnsSettingsHash() -> UInt64
    func staticProxySettingsHash() -> UInt64
}

struct NetworkPathFingerprint: Equatable, Sendable {
    let interfaceType: String?
    let interfaceName: String?
    let pathStatus: NetworkPathState
    let tunnelInterfaces: [String]
    let routedTunnelInterface: String?

    init(
        interfaceType: String?,
        interfaceName: String?,
        pathStatus: NetworkPathState,
        tunnelInterfaces: [String] = [],
        routedTunnelInterface: String? = nil
    ) {
        self.interfaceType = interfaceType
        self.interfaceName = interfaceName
        self.pathStatus = pathStatus
        self.tunnelInterfaces = tunnelInterfaces
        self.routedTunnelInterface = routedTunnelInterface
    }
}

enum NetworkTunnelInterfaceClassifier {
    static let prefixes = ["utun", "ipsec", "ppp"]

    static func tunnelInterfaces(from names: [String]) -> [String] {
        names.filter { name in
            prefixes.contains { name.hasPrefix($0) }
        }.sorted()
    }

    static func routedTunnelInterface(
        activeInterfaceName: String?,
        tunnelInterfaces: [String]
    ) -> String? {
        guard let activeInterfaceName,
              tunnelInterfaces.contains(activeInterfaceName) else {
            return nil
        }
        return activeInterfaceName
    }
}

struct SystemNetworkTunnelStateReader {
    static func state(for path: NWPath) -> (
        tunnelInterfaces: [String],
        routedTunnelInterface: String?
    ) {
        let interfaceNames = NetworkInfoService.fetchAll().map(\.interfaceName)
        let tunnels = NetworkTunnelInterfaceClassifier.tunnelInterfaces(from: interfaceNames)
        let activeInterface = path.availableInterfaces
            .filter { path.usesInterfaceType($0.type) }
            .sorted { lhs, rhs in
                if lhs.type.fingerprintName != rhs.type.fingerprintName {
                    return lhs.type.fingerprintName < rhs.type.fingerprintName
                }
                return lhs.name < rhs.name
            }
            .first?.name
        return (
            tunnels,
            NetworkTunnelInterfaceClassifier.routedTunnelInterface(
                activeInterfaceName: activeInterface,
                tunnelInterfaces: tunnels
            )
        )
    }
}

protocol NetworkPathFingerprintSourcing: Sendable {
    func pathFingerprintChanges() -> AsyncStream<NetworkPathFingerprint>
}

protocol NetworkFingerprintSettingsPolling: Sendable {
    func ticks(every interval: Duration) -> AsyncStream<Void>
}

struct SystemNetworkFingerprintSettingsPoller: NetworkFingerprintSettingsPolling {
    func ticks(every interval: Duration) -> AsyncStream<Void> {
        AsyncStream { continuation in
            let task = Task {
                while !Task.isCancelled {
                    try? await Task.sleep(for: interval)
                    guard !Task.isCancelled else { break }
                    continuation.yield(())
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}

struct SystemNetworkPathFingerprintSource: NetworkPathFingerprintSourcing {
    func pathFingerprintChanges() -> AsyncStream<NetworkPathFingerprint> {
        pathFingerprintStream()
    }

    private func pathFingerprintStream() -> AsyncStream<NetworkPathFingerprint> {
        let monitor = NWPathMonitor()
        return AsyncStream { continuation in
            monitor.pathUpdateHandler = { path in
                continuation.yield(Self.fingerprint(for: path))
            }
            continuation.onTermination = { _ in monitor.cancel() }
            monitor.start(queue: DispatchQueue(
                label: "io.github.kaoru.wifi-lens.network-diagnostics.fingerprint-path"
            ))
        }
    }

    private static func fingerprint(for path: NWPath) -> NetworkPathFingerprint {
        let activeInterface = path.availableInterfaces
            .filter { path.usesInterfaceType($0.type) }
            .sorted { lhs, rhs in
                if lhs.type.fingerprintName != rhs.type.fingerprintName {
                    return lhs.type.fingerprintName < rhs.type.fingerprintName
                }
                return lhs.name < rhs.name
            }
            .first
        let tunnelState = SystemNetworkTunnelStateReader.state(for: path)
        return NetworkPathFingerprint(
            interfaceType: activeInterface?.type.fingerprintName,
            interfaceName: activeInterface?.name,
            pathStatus: path.status.fingerprintState,
            tunnelInterfaces: tunnelState.tunnelInterfaces,
            routedTunnelInterface: tunnelState.routedTunnelInterface
        )
    }
}

struct SystemNetworkFingerprintSettingsReader: NetworkFingerprintSettingsReading {
    private static let dnsKeys: Set<String> = [
        "DomainName", "Options", "SearchDomains", "SearchOrder",
        "ServerAddresses", "ServerPort", "ServerTimeout", "SortList",
        "SupplementalMatchDomains", "SupplementalMatchDomainsNoSearch",
    ]
    private static let staticProxyKeys = [
        "HTTPEnable", "HTTPProxy", "HTTPPort",
        "HTTPSEnable", "HTTPSProxy", "HTTPSPort",
        "SOCKSEnable", "SOCKSProxy", "SOCKSPort",
        "ProxyAutoConfigEnable", "ProxyAutoConfigURLString", "ProxyAutoDiscoveryEnable",
        "ExceptionsList", "ExcludeSimpleHostnames",
    ]

    func dnsSettingsHash() -> UInt64 {
        let patterns = ["State:/Network/(Global|Service/.+)/DNS"] as CFArray
        let settings = SCDynamicStoreCopyMultiple(nil, nil, patterns) as? [String: Any]
        let dnsSettings = (settings ?? [:]).mapValues { value -> Any in
            guard let dictionary = value as? [String: Any] else { return value }
            return dictionary.filter { Self.dnsKeys.contains($0.key) }
        }
        return StableNetworkSettingsHash.value(for: dnsSettings)
    }

    func staticProxySettingsHash() -> UInt64 {
        guard let settings = CFNetworkCopySystemProxySettings()?.takeRetainedValue() as? [String: Any] else {
            return Self.proxySettingsHash(for: [:])
        }
        return Self.proxySettingsHash(for: settings)
    }

    static func proxySettingsHash(for settings: [String: Any]) -> UInt64 {
        let staticSettings = Dictionary(uniqueKeysWithValues: Self.staticProxyKeys.compactMap { key in
            settings[key].map { (key, $0) }
        })
        return StableNetworkSettingsHash.value(for: staticSettings)
    }
}

struct SystemNetworkFingerprintMonitor: NetworkFingerprintMonitoring {
    private let settingsReader: any NetworkFingerprintSettingsReading
    private let pathSource: any NetworkPathFingerprintSourcing
    private let settingsPoller: any NetworkFingerprintSettingsPolling
    private let settingsPollInterval: Duration

    init(
        settingsReader: any NetworkFingerprintSettingsReading = SystemNetworkFingerprintSettingsReader(),
        pathSource: any NetworkPathFingerprintSourcing = SystemNetworkPathFingerprintSource(),
        settingsPoller: any NetworkFingerprintSettingsPolling = SystemNetworkFingerprintSettingsPoller(),
        settingsPollInterval: Duration = .milliseconds(250)
    ) {
        self.settingsReader = settingsReader
        self.pathSource = pathSource
        self.settingsPoller = settingsPoller
        self.settingsPollInterval = settingsPollInterval
    }

    func observation() async -> NetworkFingerprintObservation? {
        let pathStream = pathSource.pathFingerprintChanges()
        var pathIterator = pathStream.makeAsyncIterator()
        guard let baselinePath = await pathIterator.next() else { return nil }

        let baseline = fingerprint(path: baselinePath)
        let remainingPathIterator = NetworkPathFingerprintIterator(pathIterator)
        let emissionState = NetworkFingerprintEmissionState(baseline: baseline)
        let streamPair = AsyncStream<NetworkFingerprint>.makeStream()
        let task = Task {
            await withTaskGroup(of: Void.self) { group in
                group.addTask {
                    while let path = await remainingPathIterator.next() {
                        guard !Task.isCancelled else { return }
                        let fingerprint = fingerprint(path: path)
                        if let emitted = await emissionState.receivePath(fingerprint) {
                            streamPair.continuation.yield(emitted)
                        }
                    }
                }
                group.addTask {
                    for await _ in settingsPoller.ticks(every: settingsPollInterval) {
                        guard !Task.isCancelled else { return }
                        if let fingerprint = await emissionState.receiveSettings(
                            dnsSettingsHash: settingsReader.dnsSettingsHash(),
                            staticProxySettingsHash: settingsReader.staticProxySettingsHash()
                        ) {
                            streamPair.continuation.yield(fingerprint)
                        }
                    }
                }
                await group.waitForAll()
            }
            streamPair.continuation.finish()
        }
        streamPair.continuation.onTermination = { _ in task.cancel() }
        return NetworkFingerprintObservation(
            baseline: baseline,
            changes: streamPair.stream
        )
    }

    private func fingerprint(path: NetworkPathFingerprint) -> NetworkFingerprint {
        NetworkFingerprint(
            interfaceType: path.interfaceType,
            interfaceName: path.interfaceName,
            pathStatus: path.pathStatus,
            dnsSettingsHash: settingsReader.dnsSettingsHash(),
            staticProxySettingsHash: settingsReader.staticProxySettingsHash(),
            tunnelInterfaces: path.tunnelInterfaces,
            routedTunnelInterface: path.routedTunnelInterface
        )
    }
}

private final class NetworkPathFingerprintIterator: @unchecked Sendable {
    private var iterator: AsyncStream<NetworkPathFingerprint>.Iterator

    init(_ iterator: AsyncStream<NetworkPathFingerprint>.Iterator) {
        self.iterator = iterator
    }

    func next() async -> NetworkPathFingerprint? {
        await iterator.next()
    }
}

private actor NetworkFingerprintEmissionState {
    private var latest: NetworkFingerprint

    init(baseline: NetworkFingerprint) {
        latest = baseline
    }

    func receivePath(_ fingerprint: NetworkFingerprint) -> NetworkFingerprint? {
        guard fingerprint != latest else { return nil }
        latest = fingerprint
        return fingerprint
    }

    func receiveSettings(
        dnsSettingsHash: UInt64,
        staticProxySettingsHash: UInt64
    ) -> NetworkFingerprint? {
        guard
            dnsSettingsHash != latest.dnsSettingsHash
                || staticProxySettingsHash != latest.staticProxySettingsHash
        else {
            return nil
        }
        let fingerprint = NetworkFingerprint(
            interfaceType: latest.interfaceType,
            interfaceName: latest.interfaceName,
            pathStatus: latest.pathStatus,
            dnsSettingsHash: dnsSettingsHash,
            staticProxySettingsHash: staticProxySettingsHash,
            tunnelInterfaces: latest.tunnelInterfaces,
            routedTunnelInterface: latest.routedTunnelInterface
        )
        latest = fingerprint
        return fingerprint
    }
}

private enum StableNetworkSettingsHash {
    static func value(for value: Any) -> UInt64 {
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in canonical(value).utf8 {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        return hash
    }

    private static func canonical(_ value: Any) -> String {
        if let dictionary = value as? [String: Any] {
            return dictionary.keys.sorted().map { key in
                "\(key)=\(canonical(dictionary[key] as Any))"
            }.joined(separator: "|")
        }
        if let dictionary = value as? NSDictionary {
            let swiftDictionary = dictionary.reduce(into: [String: Any]()) { result, item in
                result[String(describing: item.key)] = item.value
            }
            return canonical(swiftDictionary)
        }
        if let array = value as? [Any] {
            return array.map(canonical).joined(separator: ",")
        }
        if let data = value as? Data {
            return data.base64EncodedString()
        }
        return String(describing: value)
    }
}

private extension NWInterface.InterfaceType {
    var fingerprintName: String {
        switch self {
        case .wifi: "wifi"
        case .wiredEthernet: "wiredEthernet"
        case .cellular: "cellular"
        case .loopback: "loopback"
        case .other: "other"
        @unknown default: "unknown"
        }
    }
}

private extension NWPath.Status {
    var fingerprintState: NetworkPathState {
        switch self {
        case .satisfied: .satisfied
        case .unsatisfied: .unsatisfied
        case .requiresConnection: .requiresConnection
        @unknown default: .requiresConnection
        }
    }
}
