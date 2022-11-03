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
        let approveCurve: String
        let supportCurve: String
        let callHash: String?
    }
}
