import Foundation
import WalletConnectSign

enum WalletConnectProposalDecision {
    case approve(proposal: Session.Proposal, namespaces: [String: SessionNamespace])
    case reject(proposal: Session.Proposal)
}

struct WalletConnectSignDecision {
    let request: Request
    let result: RPCResult

    static func approve(request: Request, signature: AnyCodable) -> WalletConnectSignDecision {
        .init(request: request, result: .response(signature))
    }

    static func reject(request: Request) -> WalletConnectSignDecision {
        let error = WalletConnectSign.JSONRPCError(
            code: 4001,
            message: "Rejected",
            data: nil
        )

        return .init(request: request, result: .error(error))
    }
}
