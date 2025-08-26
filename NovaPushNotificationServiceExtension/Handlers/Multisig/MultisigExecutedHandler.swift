import Foundation
import Operation_iOS

final class MultisigExecutedHandler: CommonMultisigHandler, PushNotificationHandler {
    override func createTitle(params _: MultisigNotificationParams) -> String {
        R.string.localizable.pushNotificationMultisigExecutedTitle(
            preferredLanguages: locale.rLanguages
        )
    }

    override func createBody(
        using _: MultisigPayloadProtocol,
        params: MultisigNotificationParams
    ) -> String {
        R.string.localizable.pushNotificationMultisigExecutedBody(
            params.signatory,
            preferredLanguages: locale.rLanguages
        )
    }
}
