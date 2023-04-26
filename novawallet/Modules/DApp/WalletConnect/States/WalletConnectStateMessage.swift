import Foundation
import WalletConnectSwiftV2

enum WalletConnectStateMessage {
    case proposal(Session.Proposal)
    case request(Request)
}
