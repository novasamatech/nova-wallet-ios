import Foundation
import Operation_iOS

final class MultisigCancelledHandler: CommonMultisigHandler, PushNotificationHandler {
    override func createTitle(params _: MultisigNotificationParams) -> String {
        R.string(preferredLanguages: locale.rLanguages).localizable.pushNotificationMultisigCancelledTitle()
    }

    override func createBody(
        using _: MultisigPayloadProtocol,
        params: MultisigNotificationParams
    ) -> String {
        R.string(preferredLanguages: locale.rLanguages).localizable.pushNotificationMultisigCancelledBody(
            params.signatory
        )
    }
}
