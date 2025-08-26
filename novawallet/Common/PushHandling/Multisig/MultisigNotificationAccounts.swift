import Foundation

struct MultisigNotificationParams {
    let signatory: String
    let multisigName: String
    let multisigAccount: DelegatedAccount.MultisigAccountModel
}
