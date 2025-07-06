import Foundation

struct MultisigTxDetailsViewModel {
    let title: String
    let sections: [Section]
}

extension MultisigTxDetailsViewModel {
    enum Section {
        case deposit(Deposit)
        case callData(CallData)
        case callJson(SectionField<String>)
    }
}

extension MultisigTxDetailsViewModel {
    struct SectionField<T> {
        let title: String
        let value: T
    }

    struct Deposit {
        let depositor: SectionField<DisplayAddressViewModel>
        let deposit: SectionField<BalanceViewModelProtocol>
    }

    struct CallData {
        let callHash: SectionField<StackCellViewModel>
        let callData: SectionField<StackCellViewModel>?
    }
}
