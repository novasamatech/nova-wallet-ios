import Foundation

struct MultisigOperationConfirmViewModel {
    let title: String
    let amount: BalanceViewModelProtocol?
    let sections: [Section]
    let actions: [Action]

    var hasAddCallDataAction: Bool {
        actions.contains { $0.type == .addCallData }
    }
}

extension MultisigOperationConfirmViewModel {
    enum Section {
        case origin(OriginModel)
        case recipient(RecipientModel)
        case signatory(SignatoryModel)
        case signatories(SignatoriesModel)
        case fullDetails(FullDetailsModel)
    }

    struct Action {
        let title: String
        let type: ActionType
        let actionClosure: ActionClosure
    }

    enum ActionType {
        case approve
        case reject
        case addCallData
    }

    typealias ActionClosure = () -> Void
}

extension MultisigOperationConfirmViewModel {
    struct SectionField<T> {
        let title: String
        let value: T
    }

    struct OriginModel {
        let network: SectionField<NetworkViewModel>
        let wallet: SectionField<StackCellViewModel>
        let onBehalfOf: SectionField<DisplayAddressViewModel>?
    }

    struct RecipientModel {
        let recipient: SectionField<DisplayAddressViewModel>?
    }

    struct SignatoryModel {
        let wallet: SectionField<StackCellViewModel>
        let fee: SectionField<BalanceViewModelProtocol?>
    }

    struct SignatoriesModel {
        let signatories: SectionField<SignatoryListViewModel>
    }

    typealias FullDetailsModel = SectionField<String>
}
