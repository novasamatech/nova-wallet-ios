import Foundation

final class NewMultisigHandler: CommonMultisigHandler, PushNotificationHandler {
    override func createTitle(using _: MultisigPayloadProtocol) -> String {
        R.string.localizable.pushNotificationMultisigNewTitle(
            preferredLanguages: locale.rLanguages
        )
    }

    override func createBody(
        using payload: MultisigPayloadProtocol,
        walletNames: MultisigNotificationAccounts
    ) -> String {
        R.string.localizable.pushNotificationMultisigNewBody(
            walletNames.signatory ?? payload.signatoryAddress.mediumTruncated,
            preferredLanguages: locale.rLanguages
        )
    }
}
