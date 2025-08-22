import Foundation
import Operation_iOS

final class MultisigExecutedHandler: CommonMultisigHandler, PushNotificationHandler {
    override func createTitle(using _: MultisigPayloadProtocol) -> String {
        R.string.localizable.pushNotificationMultisigExecutedTitle(
            preferredLanguages: locale.rLanguages
        )
    }

    override func createBody(
        using payload: MultisigPayloadProtocol,
        walletNames: MultisigNotificationAccounts
    ) -> String {
        R.string.localizable.pushNotificationMultisigExecutedBody(
            walletNames.signatory ?? payload.signatoryAddress.mediumTruncated,
            preferredLanguages: locale.rLanguages
        )
    }
}
