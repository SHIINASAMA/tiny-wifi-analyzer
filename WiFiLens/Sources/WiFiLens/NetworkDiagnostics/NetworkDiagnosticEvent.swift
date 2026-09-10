import Foundation

enum DiagnosticEventKind: Equatable, Sendable {
    case sessionStarted
    case runStarted
    case checkStarted
    case checkFinished
    case restarted
    case timedOut
    case cancelled
    case completed
}

struct NetworkDiagnosticEvent: Equatable, Sendable {
    let runID: UUID
    let elapsedMilliseconds: Int64
    let kind: DiagnosticEventKind
    let checkID: NetworkDiagnosticCheckID?
    let reasonCode: String?

    func formatted() -> String {
        let elapsed = String(max(0, elapsedMilliseconds)) + "ms"
        switch kind {
        case .sessionStarted:
            return elapsed + " · Session started"
        case .runStarted:
            return elapsed + " · Run started"
        case .checkStarted:
            return elapsed + " · Checking " + (checkID?.logTitle ?? "diagnostic") + "…"
        case .checkFinished:
            return elapsed + " · " + (checkID?.logTitle ?? "Diagnostic") + " finished"
        case .restarted:
            return elapsed + " · Network changed; restarting (" + Self.reasonTitle(reasonCode) + ")"
        case .timedOut:
            return elapsed + " · Check timed out"
        case .cancelled:
            return elapsed + " · Check cancelled"
        case .completed:
            return elapsed + " · Check completed"
        }
    }

    private static func reasonTitle(_ reasonCode: String?) -> String {
        switch reasonCode {
        case .some("route"):
            "route"
        case .some("address"):
            "address"
        case .some("dns"):
            "DNS"
        case .some("proxy"):
            "proxy"
        case .some("path"):
            "path"
        case .some("network-change"):
            "network change"
        default:
            "network state"
        }
    }
}
