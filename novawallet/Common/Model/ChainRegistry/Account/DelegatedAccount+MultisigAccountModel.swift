import Foundation
import Operation_iOS

extension DelegatedAccount {
    struct MultisigAccountModel: DelegatedAccountProtocol {
        let accountId: AccountId
        let signatory: AccountId
        let otherSignatories: [AccountId]
        let threshold: Int
        let status: Status

        func getAllSignatories() -> [AccountId] {
            [signatory] + otherSignatories
        }

        func getAllSignatoriesInOrder() -> [AccountId] {
            getAllSignatories().sorted { $0.lexicographicallyPrecedes($1) }
        }

        func getOtherSignatoriesInOrder() -> [AccountId] {
            otherSignatories.sorted { $0.lexicographicallyPrecedes($1) }
        }
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
