import Foundation

struct MultisigNotificationsModel {
    var signatureRequested: Bool
    var signedBySignatory: Bool
    var transactionExecuted: Bool
    var transactionRejected: Bool

    init(
        signatureRequested: Bool = false,
        signedBySignatory: Bool = false,
        transactionExecuted: Bool = false,
        transactionRejected: Bool = false
    ) {
        self.signatureRequested = signatureRequested
        self.signedBySignatory = signedBySignatory
        self.transactionExecuted = transactionExecuted
        self.transactionRejected = transactionRejected
    }

    init(from localSettings: Web3Alert.LocalSettings?) {
        if let localSettings {
            self = .init(
                signatureRequested: localSettings.notifications.newMultisig != nil,
                signedBySignatory: localSettings.notifications.multisigApproval != nil,
                transactionExecuted: localSettings.notifications.multisigExecuted != nil,
                transactionRejected: localSettings.notifications.multisigCancelled != nil
            )
        } else {
            self = .empty()
        }
    }

    var isEnabled: Bool {
        signatureRequested || signedBySignatory || transactionExecuted || transactionRejected
    }

    static func empty() -> MultisigNotificationsModel {
        .init()
    }
}
