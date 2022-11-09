import Foundation

enum ReferendumFullDetailsViewModel {
    struct Proposer {
        let proposer: DisplayAddressViewModel
        let deposit: BalanceViewModelProtocol?
    }

    struct Beneficiary {
        let account: DisplayAddressViewModel
        let amount: BalanceViewModelProtocol?
    }

    struct CurveAndHash {
        let vote: CurveAndHashVoting
        let turnout: BalanceViewModelProtocol
        let electorate: BalanceViewModelProtocol
        let callHash: String?
    }

    enum CurveAndHashVoting {
        case supportAndVotes(approveCurve: String, supportCurve: String)
        case threshold(function: String)
    }
}
