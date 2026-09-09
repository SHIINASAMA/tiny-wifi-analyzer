import Foundation

struct DiagnosticGatewayTarget: Equatable, Sendable {
    let interfaceName: String
    let interfaceIndex: UInt32
    let address: String
}

enum DiagnosticRouteSelection: Equatable, Sendable {
    case selected(DiagnosticGatewayTarget)
    case unavailable
    case ambiguous
    case unsupported
}

protocol DiagnosticRouteSourcing: Sendable {
    func currentRoute(timeout: Duration) async -> DiagnosticRouteSelection
}
