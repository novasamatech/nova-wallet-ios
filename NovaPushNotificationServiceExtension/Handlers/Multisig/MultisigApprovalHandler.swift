import Foundation

final class MultisigApprovalHandler: CommonMultisigHandler, PushNotificationHandler {
    override func createTitle(using payload: MultisigPayloadProtocol) -> String {
        R.string.localizable.pushNotificationMultisigApprovalTitle(
            payload.signatoryAddress.mediumTruncated,
            preferredLanguages: locale.rLanguages
        )
    }

    override func createBody(using _: MultisigPayloadProtocol) -> String {
        ""
    }
}
