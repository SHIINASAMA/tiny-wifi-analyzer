import Foundation

enum NetworkDiagnosticStatus: String, CaseIterable, Equatable, Sendable {
    case normal, abnormal, indeterminate, blocked, skipped

    var logTitle: String {
        switch self {
        case .normal:
            "Normal"
        case .abnormal:
            "Abnormal"
        case .indeterminate:
            "Indeterminate"
        case .blocked:
            "Blocked"
        case .skipped:
            "Skipped"
        }
    }
}

enum NetworkDiagnosticCheckID: String, CaseIterable, Equatable, Hashable, Sendable {
    case path, gatewayReachability, dns, internet, ipv6, proxy

    var logTitle: String {
        switch self {
        case .path:
            "Network Path"
        case .gatewayReachability:
            "Gateway Reachability"
        case .dns:
            "DNS Resolution"
        case .internet:
            "Internet Access"
        case .ipv6:
            "IPv6 Connectivity"
        case .proxy:
            "System Proxy"
        }
    }

    var localizedTitle: String {
        switch self {
        case .path:
            String(localized: "network_diagnostics.check.path.title", comment: "Network system path check title")
        case .gatewayReachability:
            String(localized: "network_diagnostics.check.gateway_reachability.title", comment: "Gateway reachability check title")
        case .dns:
            String(localized: "network_diagnostics.check.dns.title", comment: "DNS resolution check title")
        case .internet:
            String(localized: "network_diagnostics.check.internet.title", comment: "Internet access check title")
        case .ipv6:
            String(localized: "network_diagnostics.check.ipv6.title", comment: "Optional forced IPv6 access check title")
        case .proxy:
            String(localized: "network_diagnostics.check.proxy.title", comment: "System proxy check title")
        }
    }
}

struct NetworkDiagnosticsLogStore: Equatable, Sendable {
    private(set) var lines: [String] = []

    var text: String {
        lines.joined(separator: "\n")
    }

    mutating func append(_ line: String) {
        lines.append(line)
    }

    mutating func reset() {
        lines.removeAll(keepingCapacity: true)
    }
}

enum NetworkDiagnosticStatusTone: Equatable, Sendable {
    case success
    case error
    case caution
    case informational
    case muted
}

struct NetworkDiagnosticStatusPresentation: Equatable, Sendable {
    let labelKey: String
    let icon: String
    let tone: NetworkDiagnosticStatusTone
}

extension NetworkDiagnosticStatus {
    var presentation: NetworkDiagnosticStatusPresentation {
        switch self {
        case .normal:
            .init(labelKey: "network_diagnostics.status.normal", icon: "checkmark.circle.fill", tone: .success)
        case .abnormal:
            .init(labelKey: "network_diagnostics.status.abnormal", icon: "xmark.circle.fill", tone: .error)
        case .indeterminate:
            .init(labelKey: "network_diagnostics.status.indeterminate", icon: "questionmark.circle.fill", tone: .caution)
        case .blocked:
            .init(labelKey: "network_diagnostics.status.blocked", icon: "lock.fill", tone: .informational)
        case .skipped:
            .init(labelKey: "network_diagnostics.status.skipped", icon: "forward.fill", tone: .muted)
        }
    }

    var localizedTitle: String {
        String(
            localized: .init(stringLiteral: presentation.labelKey),
            comment: "Network self-check status title"
        )
    }
}

struct NetworkDiagnosticEvidence: Equatable, Sendable {
    let code: String
    let value: String?
}

struct NetworkDiagnosticRemediation: Equatable, Sendable {
    let detectionKey: String
    let causeKey: String
    let actionKey: String
    let rerunKey: String

    static func forResult(_ result: NetworkDiagnosticResult) -> Self {
        let codes = Set(result.evidence.map(\.code))
        let base: (String, String, String) = if codes.contains("proxy.authentication-required") {
            (
                "network_diagnostics.remediation.proxy_authentication.detection",
                "network_diagnostics.remediation.proxy_authentication.cause",
                "network_diagnostics.remediation.proxy_authentication.action"
            )
        } else if codes.contains("captive-portal.suspected") || codes.contains("captive-portal.redirect") {
            (
                "network_diagnostics.remediation.captive_portal.detection",
                "network_diagnostics.remediation.captive_portal.cause",
                "network_diagnostics.remediation.captive_portal.action"
            )
        } else if codes.contains("https.certificate-time-error") {
            (
                "network_diagnostics.remediation.certificate_time.detection",
                "network_diagnostics.remediation.certificate_time.cause",
                "network_diagnostics.remediation.certificate_time.action"
            )
        } else if codes.contains("proxy.endpoint-unavailable") || codes.contains("proxy.egress-unavailable") {
            (
                "network_diagnostics.remediation.proxy_unavailable.detection",
                "network_diagnostics.remediation.proxy_unavailable.cause",
                "network_diagnostics.remediation.proxy_unavailable.action"
            )
        } else if result.id == .dns && result.status == .abnormal {
            (
                "network_diagnostics.remediation.dns_unavailable.detection",
                "network_diagnostics.remediation.dns_unavailable.cause",
                "network_diagnostics.remediation.dns_unavailable.action"
            )
        } else if result.id == .path && result.status == .abnormal {
            (
                "network_diagnostics.remediation.path_unavailable.detection",
                "network_diagnostics.remediation.path_unavailable.cause",
                "network_diagnostics.remediation.path_unavailable.action"
            )
        } else if result.status == .indeterminate {
            (
                "network_diagnostics.remediation.indeterminate.detection",
                "network_diagnostics.remediation.indeterminate.cause",
                "network_diagnostics.remediation.indeterminate.action"
            )
        } else {
            (
                "network_diagnostics.remediation.generic.detection",
                "network_diagnostics.remediation.generic.cause",
                "network_diagnostics.remediation.generic.action"
            )
        }

        return .init(
            detectionKey: base.0,
            causeKey: base.1,
            actionKey: base.2,
            rerunKey: "network_diagnostics.remediation.rerun"
        )
    }
}

extension NetworkDiagnosticConclusion {
    static func primaryIssue(in results: [NetworkDiagnosticResult]) -> NetworkDiagnosticResult? {
        let priority: [NetworkDiagnosticCheckID] = [.path, .gatewayReachability, .dns, .internet, .proxy]
        return priority.compactMap { id in
            results.first {
                $0.id == id && ($0.status == .abnormal || $0.status == .indeterminate)
            }
        }.first
    }
}

enum NetworkDiagnosticStage: CaseIterable, Equatable, Sendable {
    case thisMac
    case lan
    case internet

    var contributingCheckIDs: [NetworkDiagnosticCheckID] {
        switch self {
        case .thisMac: [.path, .dns, .proxy]
        case .lan: [.gatewayReachability]
        case .internet: [.internet]
        }
    }
}

struct NetworkDiagnosticStageResolver: Sendable {
    func status(
        for stage: NetworkDiagnosticStage,
        results: [NetworkDiagnosticCheckID: NetworkDiagnosticResult]
    ) -> NetworkDiagnosticStatus? {
        let contributingIDs = stage.contributingCheckIDs
        let contributing = contributingIDs.compactMap { results[$0] }
        guard contributing.count == contributingIDs.count else { return nil }

        if contributing.contains(where: { $0.status == .abnormal }) {
            return .abnormal
        }
        if contributing.contains(where: { $0.status == .indeterminate }) {
            return .indeterminate
        }
        if contributing.allSatisfy({ $0.status == .blocked }) {
            return .blocked
        }
        return .normal
    }
}

struct NetworkDiagnosticResult: Equatable, Identifiable, Sendable {
    let id: NetworkDiagnosticCheckID
    let status: NetworkDiagnosticStatus
    let summary: String
    let detail: String?
    let evidence: [NetworkDiagnosticEvidence]

    init(
        id: NetworkDiagnosticCheckID,
        status: NetworkDiagnosticStatus,
        summary: String,
        detail: String? = nil,
        evidence: [NetworkDiagnosticEvidence] = []
    ) {
        self.id = id
        self.status = status
        self.summary = summary
        self.detail = detail
        self.evidence = evidence
    }

    static func blocked(id: NetworkDiagnosticCheckID, summary: String) -> Self {
        .init(id: id, status: .blocked, summary: summary, detail: summary)
    }
}

enum NetworkDiagnosticConclusion: String, Equatable, Sendable {
    case networkNormal
    case needsAttention
    case networkUnavailable

    static func evaluate(
        _ results: [NetworkDiagnosticResult],
        requiredIDs: Set<NetworkDiagnosticCheckID> = Set(NetworkDiagnosticCheckID.allCases)
    ) -> Self? {
        let resultsByID = Dictionary(uniqueKeysWithValues: results.map { ($0.id, $0) })
        guard Set(resultsByID.keys) == requiredIDs else {
            return nil
        }

        if resultsByID[.path]?.status == .abnormal {
            return .networkUnavailable
        }
        if let internet = resultsByID[.internet],
           internet.status == .abnormal,
           !internet.evidence.contains(where: { $0.code == "https.available" }),
           !hasAvailableHTTPSProxy(resultsByID[.proxy]),
           internet.evidence.contains(where: { $0.code == "https.connectivity-error" }) {
            return .networkUnavailable
        }
        if resultsByID.values.contains(where: { result in
            result.status != .normal
                && result.id != .ipv6
                && !isUnverifiedDirectRouteNeutral(
                    result,
                    internet: resultsByID[.internet]
                )
        }) {
            return .needsAttention
        }
        return .networkNormal
    }

    private static func hasAvailableHTTPSProxy(_ result: NetworkDiagnosticResult?) -> Bool {
        guard result?.status == .normal else { return false }
        return result?.evidence.contains { evidence in
            guard evidence.code == "proxy.https.egress-status",
                  let value = evidence.value,
                  let statusCode = Int(value) else {
                return false
            }
            return (200..<300).contains(statusCode)
        } == true
    }

    private static func isUnverifiedDirectRouteNeutral(
        _ result: NetworkDiagnosticResult,
        internet: NetworkDiagnosticResult?
    ) -> Bool {
        result.id == .proxy
            && result.status == .indeterminate
            && internet?.status == .normal
            && result.evidence.contains { evidence in
                evidence.code.hasSuffix(".egress-status") && evidence.value == "base-check"
            }
    }
}
