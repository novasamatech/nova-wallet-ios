import Foundation
import Operation_iOS

extension DelegatedAccount {
    struct MultisigAccountModel: DelegatedAccountProtocol {
        let accountId: AccountId
        let signatory: AccountId
        let otherSignatories: [AccountId]
        let threshold: Int
        let status: Status
    }
}

extension DelegatedAccount.MultisigAccountModel: Identifiable {
    var identifier: String {
        accountId.toHex()
    }
}

extension DelegatedAccount.MultisigAccountModel {
    func replacingStatus(_ newStatus: DelegatedAccount.Status) -> Self {
        .init(
            accountId: accountId,
            signatory: signatory,
            otherSignatories: otherSignatories,
            threshold: threshold,
            status: newStatus
        )
    }
}
