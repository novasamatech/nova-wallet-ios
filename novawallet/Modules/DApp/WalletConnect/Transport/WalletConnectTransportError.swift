import Foundation

enum WalletConnectTransportError: Error {
    case stateFailed(WalletConnectStateError)
    case signingDecisionSubmissionFailed(Error)
    case proposalDecisionSubmissionFailed(Error)
}
