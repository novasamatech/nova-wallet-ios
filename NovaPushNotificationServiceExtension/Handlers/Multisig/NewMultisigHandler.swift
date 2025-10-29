import Foundation

final class NewMultisigHandler: CommonMultisigHandler, PushNotificationHandler {
    override func createTitle(params _: MultisigNotificationParams) -> String {
        R.string(preferredLanguages: locale.rLanguages).localizable.pushNotificationMultisigNewTitle()
    }

    override func createBody(
        using _: MultisigPayloadProtocol,
        params: MultisigNotificationParams
    ) -> String {
        R.string(preferredLanguages: locale.rLanguages).localizable.pushNotificationMultisigNewBody(
            params.signatory
        )
    }
}
