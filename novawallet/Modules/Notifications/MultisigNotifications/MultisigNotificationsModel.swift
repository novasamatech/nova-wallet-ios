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
                signatureRequested: localSettings.notifications.multisigSignatureRequested != nil,
                signedBySignatory: localSettings.notifications.multisigSignedBySignatory != nil,
                transactionExecuted: localSettings.notifications.multisigTransactionExecuted != nil,
                transactionRejected: localSettings.notifications.multisigTransactionRejected != nil
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
