import Foundation
import SubstrateSdk

struct MultisigOperationViewModel {
    let identifier: String
    let chainIcon: DiffableNetworkViewModel
    let iconViewModel: ImageViewModelProtocol
    let operationTitle: String
    let operationSubtitle: String?
    let amount: String?
    let timeString: String
    let signingProgress: String
    let status: Status?
    let delegatedAccountModel: (text: String, model: DisplayAddressViewModel)?

    enum Status: Hashable {
        case createdByUser(String)
        case signed(String)
    }
}

extension MultisigOperationViewModel: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(identifier)
        hasher.combine(operationTitle)
        hasher.combine(signingProgress)
        hasher.combine(status)
        hasher.combine(chainIcon)
    }

    static func == (lhs: MultisigOperationViewModel, rhs: MultisigOperationViewModel) -> Bool {
        lhs.identifier == rhs.identifier &&
            lhs.operationTitle == rhs.operationTitle &&
            lhs.signingProgress == rhs.signingProgress &&
            lhs.status == rhs.status &&
            lhs.chainIcon == rhs.chainIcon
    }
}

// MARK: - Section Models

struct MultisigOperationSection {
    let title: String
    let operations: [MultisigOperationViewModel]
}

extension MultisigOperationSection: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(title)
    }

    static func == (lhs: MultisigOperationSection, rhs: MultisigOperationSection) -> Bool {
        lhs.title == rhs.title
    }
}
