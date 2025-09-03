import Foundation

final class MultisigApprovalHandler: CommonMultisigHandler, PushNotificationHandler {
    override func createTitle(params: MultisigNotificationParams) -> String {
        R.string(preferredLanguages: locale.rLanguages).localizable.pushNotificationMultisigApprovalTitle(
            params.signatory
        )
    }

    override func createBody(
        using payload: MultisigPayloadProtocol,
        params: MultisigNotificationParams
    ) -> String {
        guard let approvals = payload.approvals else { return "" }

        return R.string(preferredLanguages: locale.rLanguages).localizable.pushNotificationMultisigApprovalBody(
            approvals,
            params.multisigAccount.threshold
        )
    }
}
