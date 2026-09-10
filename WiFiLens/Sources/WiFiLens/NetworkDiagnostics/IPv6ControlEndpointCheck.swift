import Darwin
import Foundation
import Network
import Security
import dnssd

enum IPv6ControlEndpointLoadOutcome: Equatable, Sendable {
    case succeeded
    case failed
    case noGlobalAddress
}

protocol IPv6ControlEndpointLoading: Sendable {
    func load(url: URL, timeout: Duration) async -> IPv6ControlEndpointLoadOutcome
}

protocol GlobalIPv6AddressSourcing: Sendable {
    func hasGlobalIPv6Address() -> Bool
}

protocol IPv6AddressResolving: Sendable {
    func resolveAAAA(host: String, timeout: Duration) async -> [String]
}

protocol IPv6HTTPSConnecting: Sendable {
    func load(
        url: URL,
        ipv6Address: String,
        serverName: String,
        timeout: Duration
    ) async -> Bool
}

struct SystemIPv6ControlEndpointLoader: IPv6ControlEndpointLoading {
    private let addressSource: any GlobalIPv6AddressSourcing
    private let resolver: any IPv6AddressResolving
    private let connector: any IPv6HTTPSConnecting

    init(
        addressSource: any GlobalIPv6AddressSourcing = SystemGlobalIPv6AddressSource(),
        resolver: any IPv6AddressResolving = SystemIPv6AddressResolver(),
        connector: any IPv6HTTPSConnecting = NetworkIPv6HTTPSConnector()
    ) {
        self.addressSource = addressSource
        self.resolver = resolver
        self.connector = connector
    }

    func load(url: URL, timeout: Duration) async -> IPv6ControlEndpointLoadOutcome {
        guard addressSource.hasGlobalIPv6Address() else {
            return .noGlobalAddress
        }
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: timeout)
        guard
            url.scheme == "https",
            let serverName = url.host,
            !Task.isCancelled
        else {
            return .failed
        }
        let ipv6Addresses = await resolver.resolveAAAA(host: serverName, timeout: timeout)
        guard
            !ipv6Addresses.isEmpty,
            !Task.isCancelled
        else {
            return .failed
        }

        for (index, ipv6Address) in ipv6Addresses.enumerated() {
            guard !Task.isCancelled, clock.now < deadline else { return .failed }
            let remainingAddressCount = ipv6Addresses.count - index
            let attemptTimeout = clock.now.duration(to: deadline) / Double(remainingAddressCount)
            if await connector.load(
                url: url,
                ipv6Address: ipv6Address,
                serverName: serverName,
                timeout: attemptTimeout
            ) {
                return .succeeded
            }
        }
        return .failed
    }
}

struct IPv6ControlEndpointCheck: DiagnosticCheck {
    let id = NetworkDiagnosticCheckID.ipv6
    let endpoint = HTTPSControlEndpointCheck.stableHTTPSEndpoint

    private let loader: any IPv6ControlEndpointLoading
    private let timeout: Duration

    init(
        loader: any IPv6ControlEndpointLoading = SystemIPv6ControlEndpointLoader(),
        timeout: Duration = .seconds(5)
    ) {
        self.loader = loader
        self.timeout = timeout
    }

    func run() async -> NetworkDiagnosticResult {
        switch await loader.load(url: endpoint, timeout: timeout) {
        case .succeeded:
            NetworkDiagnosticResult(
                id: id,
                status: .normal,
                summary: String(
                    localized: "network_diagnostics.ipv6.normal.summary",
                    comment: "Network self-check forced IPv6 HTTPS success summary"
                ),
                evidence: [.init(code: "ipv6.available", value: nil)]
            )
        case .failed:
            NetworkDiagnosticResult(
                id: id,
                status: .indeterminate,
                summary: String(
                    localized: "network_diagnostics.ipv6.indeterminate.summary",
                    comment: "Network self-check forced IPv6 HTTPS unavailable advisory summary"
                ),
                evidence: [.init(code: "ipv6.unavailable", value: nil)]
            )
        case .noGlobalAddress:
            NetworkDiagnosticResult(
                id: id,
                status: .skipped,
                summary: String(
                    localized: "network_diagnostics.ipv6.skipped.summary",
                    comment: "Network self-check optional IPv6 probe skipped summary"
                ),
                evidence: [.init(code: "ipv6.no-global-address", value: nil)]
            )
        }
    }
}

struct SystemGlobalIPv6AddressSource: GlobalIPv6AddressSourcing {
    func hasGlobalIPv6Address() -> Bool {
        var addressList: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&addressList) == 0, let firstAddress = addressList else {
            return false
        }
        defer { freeifaddrs(firstAddress) }

        for interface in sequence(first: firstAddress, next: { $0.pointee.ifa_next }) {
            guard
                interface.pointee.ifa_flags & UInt32(IFF_UP) != 0,
                interface.pointee.ifa_flags & UInt32(IFF_LOOPBACK) == 0,
                let address = interface.pointee.ifa_addr,
                address.pointee.sa_family == sa_family_t(AF_INET6)
            else {
                continue
            }

            let ipv6Address = address.withMemoryRebound(to: sockaddr_in6.self, capacity: 1) {
                $0.pointee.sin6_addr
            }
            let bytes = withUnsafeBytes(of: ipv6Address) { Array($0) }
            if Self.isGlobal(bytes) {
                return true
            }
        }
        return false
    }

    private static func isGlobal(_ bytes: [UInt8]) -> Bool {
        guard bytes.count == 16 else { return false }
        if bytes.allSatisfy({ $0 == 0 }) { return false }
        if bytes.dropLast().allSatisfy({ $0 == 0 }), bytes.last == 1 { return false }
        if bytes[0] == 0xFF { return false }
        if bytes[0] == 0xFE, bytes[1] & 0xC0 == 0x80 { return false }
        if bytes[0] & 0xFE == 0xFC { return false }
        if bytes.prefix(10).allSatisfy({ $0 == 0 }), bytes[10] == 0xFF, bytes[11] == 0xFF {
            return false
        }
        return true
    }
}

struct SystemIPv6AddressResolver: IPv6AddressResolving {
    func resolveAAAA(host: String, timeout: Duration) async -> [String] {
        let context = IPv6ResolutionContext()
        return await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                guard context.install(continuation: continuation) else { return }
                var serviceRef: DNSServiceRef?
                let opaqueContext = Unmanaged.passUnretained(context).toOpaque()
                let error = DNSServiceGetAddrInfo(
                    &serviceRef,
                    0,
                    0,
                    DNSServiceProtocol(kDNSServiceProtocol_IPv6),
                    host,
                    { _, flags, _, errorCode, _, address, _, opaqueContext in
                        guard let opaqueContext else { return }
                        let context = Unmanaged<IPv6ResolutionContext>
                            .fromOpaque(opaqueContext)
                            .takeUnretainedValue()
                        guard errorCode == kDNSServiceErr_NoError, let address else {
                            context.finish()
                            return
                        }
                        context.append(Self.numericAddress(address))
                        if flags & kDNSServiceFlagsMoreComing == 0 {
                            context.finish()
                        }
                    },
                    opaqueContext
                )

                guard error == kDNSServiceErr_NoError, let serviceRef else {
                    context.finish()
                    return
                }
                IPv6DNSServiceActivation.configureThenInstall(
                    configureDelivery: {
                        DNSServiceSetDispatchQueue(
                            serviceRef,
                            DispatchQueue(label: "io.github.kaoru.wifi-lens.network-diagnostics.ipv6-dns")
                        )
                    },
                    installOwnership: {
                        context.install(serviceRef: serviceRef)
                    }
                )

                let timeoutTask = Task { [context] in
                    do {
                        try await Task.sleep(for: timeout)
                        context.finish()
                    } catch {
                        // The DNS callback completed or the caller cancelled.
                    }
                }
                context.install(timeoutTask: timeoutTask)
            }
        } onCancel: {
            context.cancel()
        }
    }

    private static func numericAddress(_ address: UnsafePointer<sockaddr>) -> String? {
        guard address.pointee.sa_family == sa_family_t(AF_INET6) else { return nil }
        var buffer = [CChar](repeating: 0, count: Int(NI_MAXHOST))
        guard getnameinfo(
            address,
            socklen_t(address.pointee.sa_len),
            &buffer,
            socklen_t(buffer.count),
            nil,
            0,
            NI_NUMERICHOST
        ) == 0 else {
            return nil
        }
        return String(
            decoding: buffer.prefix(while: { $0 != 0 }).map(UInt8.init),
            as: UTF8.self
        )
    }
}

enum IPv6DNSServiceActivation {
    static func configureThenInstall(
        configureDelivery: () -> Void,
        installOwnership: () -> Void
    ) {
        configureDelivery()
        installOwnership()
    }
}

private final class IPv6ResolutionContext: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<[String], Never>?
    private var serviceRef: DNSServiceRef?
    private var addresses: [String] = []
    private var cancellationRequested = false
    private var didFinish = false
    private var timeoutTask: Task<Void, Never>?

    func install(continuation: CheckedContinuation<[String], Never>) -> Bool {
        lock.lock()
        guard !cancellationRequested, !didFinish else {
            lock.unlock()
            continuation.resume(returning: [])
            return false
        }
        self.continuation = continuation
        lock.unlock()
        return true
    }

    func install(serviceRef: DNSServiceRef) {
        lock.lock()
        if didFinish || continuation == nil {
            lock.unlock()
            DNSServiceRefDeallocate(serviceRef)
            return
        }
        self.serviceRef = serviceRef
        lock.unlock()
    }

    func install(timeoutTask: Task<Void, Never>) {
        lock.lock()
        if didFinish {
            lock.unlock()
            timeoutTask.cancel()
            return
        }
        self.timeoutTask = timeoutTask
        lock.unlock()
    }

    func append(_ address: String?) {
        guard let address else { return }
        lock.lock()
        if !addresses.contains(address) {
            addresses.append(address)
        }
        lock.unlock()
    }

    func finish() {
        lock.lock()
        guard !didFinish else {
            lock.unlock()
            return
        }
        didFinish = true
        let continuation = self.continuation
        self.continuation = nil
        let serviceRef = self.serviceRef
        self.serviceRef = nil
        let addresses = self.addresses
        let timeoutTask = self.timeoutTask
        self.timeoutTask = nil
        lock.unlock()

        if let serviceRef {
            DNSServiceRefDeallocate(serviceRef)
        }
        timeoutTask?.cancel()
        continuation?.resume(returning: addresses)
    }

    func cancel() {
        lock.lock()
        cancellationRequested = true
        lock.unlock()
        finish()
    }
}

struct NetworkIPv6HTTPSConnector: IPv6HTTPSConnecting {
    func load(
        url: URL,
        ipv6Address: String,
        serverName: String,
        timeout: Duration
    ) async -> Bool {
        guard
            let address = IPv6Address(ipv6Address),
            let port = NWEndpoint.Port(rawValue: UInt16(url.port ?? 443))
        else {
            return false
        }

        let tlsOptions = NWProtocolTLS.Options()
        sec_protocol_options_set_tls_server_name(tlsOptions.securityProtocolOptions, serverName)
        let parameters = NWParameters(tls: tlsOptions, tcp: NWProtocolTCP.Options())
        let connection = NWConnection(
            to: .hostPort(host: .ipv6(address), port: port),
            using: parameters
        )

        let context = IPv6HTTPSConnectionContext(
            connection: connection,
            request: Self.request(for: url, serverName: serverName)
        )
        return await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                guard context.install(continuation: continuation) else { return }
                connection.stateUpdateHandler = { state in
                    switch state {
                    case .ready:
                        context.sendRequest()
                    case .failed, .cancelled:
                        context.finish(false)
                    default:
                        break
                    }
                }
                connection.start(queue: DispatchQueue(
                    label: "io.github.kaoru.wifi-lens.network-diagnostics.ipv6-https"
                ))
                let timeoutTask = Task { [context] in
                    do {
                        try await Task.sleep(for: timeout)
                        context.finish(false)
                    } catch {
                        // The connection completed or the caller cancelled.
                    }
                }
                context.install(timeoutTask: timeoutTask)
            }
        } onCancel: {
            context.cancel()
        }
    }

    private static func request(for url: URL, serverName: String) -> Data {
        var path = url.path.isEmpty ? "/" : url.path
        if let query = url.query, !query.isEmpty {
            path += "?\(query)"
        }
        return Data(
            "GET \(path) HTTP/1.1\r\nHost: \(serverName)\r\nConnection: close\r\n\r\n".utf8
        )
    }
}

private final class IPv6HTTPSConnectionContext: @unchecked Sendable {
    private let lock = NSLock()
    private let connection: NWConnection
    private let request: Data
    private var continuation: CheckedContinuation<Bool, Never>?
    private var response = Data()
    private var requestSent = false
    private var cancellationRequested = false
    private var didFinish = false
    private var timeoutTask: Task<Void, Never>?

    init(
        connection: NWConnection,
        request: Data
    ) {
        self.connection = connection
        self.request = request
    }

    func install(continuation: CheckedContinuation<Bool, Never>) -> Bool {
        lock.lock()
        guard !cancellationRequested, !didFinish else {
            lock.unlock()
            connection.cancel()
            continuation.resume(returning: false)
            return false
        }
        self.continuation = continuation
        lock.unlock()
        return true
    }

    func install(timeoutTask: Task<Void, Never>) {
        lock.lock()
        if didFinish {
            lock.unlock()
            timeoutTask.cancel()
            return
        }
        self.timeoutTask = timeoutTask
        lock.unlock()
    }

    func sendRequest() {
        lock.lock()
        guard continuation != nil, !requestSent else {
            lock.unlock()
            return
        }
        requestSent = true
        lock.unlock()

        connection.send(content: request, completion: .contentProcessed { [weak self] error in
            guard let self else { return }
            if error != nil {
                finish(false)
            } else {
                receiveResponse()
            }
        })
    }

    func finish(_ succeeded: Bool) {
        lock.lock()
        guard !didFinish else {
            lock.unlock()
            return
        }
        didFinish = true
        let continuation = self.continuation
        self.continuation = nil
        let timeoutTask = self.timeoutTask
        self.timeoutTask = nil
        lock.unlock()
        timeoutTask?.cancel()
        connection.stateUpdateHandler = nil
        connection.cancel()
        continuation?.resume(returning: succeeded)
    }

    func cancel() {
        lock.lock()
        cancellationRequested = true
        lock.unlock()
        finish(false)
    }

    private func receiveResponse() {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 8_192) { [weak self] data, _, complete, error in
            guard let self else { return }
            if let data {
                lock.lock()
                response.append(data)
                let response = self.response
                lock.unlock()
                if let status = Self.statusCode(in: response) {
                    finish((200..<300).contains(status))
                    return
                }
            }
            if complete || error != nil {
                finish(false)
            } else {
                receiveResponse()
            }
        }
    }

    private static func statusCode(in data: Data) -> Int? {
        guard
            let response = String(data: data, encoding: .utf8),
            let lineEnd = response.range(of: "\r\n"),
            !response[..<lineEnd.lowerBound].isEmpty
        else {
            return nil
        }
        let firstLine = String(response[..<lineEnd.lowerBound])
        let components = firstLine.components(separatedBy: " ")
        guard
            firstLine.hasPrefix("HTTP/"),
            components.count >= 2
        else {
            return nil
        }
        return Int(components[1])
    }
}
