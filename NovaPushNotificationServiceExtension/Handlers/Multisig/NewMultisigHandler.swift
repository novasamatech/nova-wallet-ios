import Foundation

final class NewMultisigHandler: CommonMultisigHandler, PushNotificationHandler {
    override func createTitle(params _: MultisigNotificationParams) -> String {
        R.string.localizable.pushNotificationMultisigNewTitle(
            preferredLanguages: locale.rLanguages
        )
    }

    override func createBody(
        using _: MultisigPayloadProtocol,
        params: MultisigNotificationParams
    ) -> String {
        R.string.localizable.pushNotificationMultisigNewBody(
            params.signatory,
            preferredLanguages: locale.rLanguages
        )
    }
}
