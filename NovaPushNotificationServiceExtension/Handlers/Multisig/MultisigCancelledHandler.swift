import Foundation
import Operation_iOS

final class MultisigCancelledHandler: CommonMultisigHandler, PushNotificationHandler {
    override func createTitle(params _: MultisigNotificationParams) -> String {
        R.string.localizable.pushNotificationMultisigCancelledTitle(
            preferredLanguages: locale.rLanguages
        )
    }

    override func createBody(
        using _: MultisigPayloadProtocol,
        params: MultisigNotificationParams
    ) -> String {
        R.string.localizable.pushNotificationMultisigCancelledBody(
            params.signatory,
            preferredLanguages: locale.rLanguages
        )
    }
}
