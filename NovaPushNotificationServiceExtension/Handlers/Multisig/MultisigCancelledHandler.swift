import Foundation
import Operation_iOS

final class MultisigCancelledHandler: CommonMultisigHandler, PushNotificationHandler {
    override func createTitle(using _: MultisigPayloadProtocol) -> String {
        R.string.localizable.pushNotificationMultisigCancelledTitle(
            preferredLanguages: locale.rLanguages
        )
    }

    override func createBody(
        using payload: MultisigPayloadProtocol,
        walletNames: MultisigNotificationAccounts
    ) -> String {
        R.string.localizable.pushNotificationMultisigCancelledBody(
            walletNames.signatory ?? payload.signatoryAddress.mediumTruncated,
            preferredLanguages: locale.rLanguages
        )
    }
}
