import Foundation
import Operation_iOS

final class MultisigCancelledHandler: CommonMultisigHandler, PushNotificationHandler {
    override func createTitle(using _: MultisigPayloadProtocol) -> String {
        R.string.localizable.pushNotificationMultisigCancelledTitle(
            preferredLanguages: locale.rLanguages
        )
    }

    override func createBody(using payload: MultisigPayloadProtocol) -> String {
        R.string.localizable.pushNotificationMultisigCancelledBody(
            payload.signatoryAddress.mediumTruncated,
            preferredLanguages: locale.rLanguages
        )
    }
}
