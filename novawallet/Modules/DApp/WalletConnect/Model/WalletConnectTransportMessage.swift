import Foundation
import WalletConnectSign

enum WalletConnectTransportMessage {
    case proposal(Session.Proposal)
    case request(Request, Session?)

    var host: String? {
        switch self {
        case let .proposal(proposal):
            return URL(string: proposal.proposer.url)?.host
        case .request:
            return nil
        }
    }
}
