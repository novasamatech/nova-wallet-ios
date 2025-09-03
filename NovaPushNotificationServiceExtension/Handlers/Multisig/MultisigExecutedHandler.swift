import Foundation
import Operation_iOS

final class MultisigExecutedHandler: CommonMultisigHandler, PushNotificationHandler {
    override func createTitle(params _: MultisigNotificationParams) -> String {
        R.string(preferredLanguages: locale.rLanguages).localizable.pushNotificationMultisigExecutedTitle()
    }

    override func createBody(
        using _: MultisigPayloadProtocol,
        params: MultisigNotificationParams
    ) -> String {
        R.string(preferredLanguages: locale.rLanguages).localizable.pushNotificationMultisigExecutedBody(
            params.signatory
        )
    }
}
