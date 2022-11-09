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

    struct Voting {
        let functionInfo: FunctionInfo
        let turnout: BalanceViewModelProtocol
        let electorate: BalanceViewModelProtocol
        let callHash: String?
    }

    enum FunctionInfo {
        case supportAndVotes(approveCurve: String, supportCurve: String)
        case threshold(function: String)
    }
}
