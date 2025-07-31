import Foundation

extension Multisig.MultisigDefinition {
    func signedBy(accountId: AccountId) -> Bool {
        approvals.contains(accountId)
    }

    func createdBy(accountId: AccountId) -> Bool {
        depositor == accountId
    }
}
