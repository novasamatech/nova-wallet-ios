import Foundation

final class MultisigApprovalHandler: CommonMultisigHandler, PushNotificationHandler {
    override func createTitle(params: MultisigNotificationParams) -> String {
        R.string.localizable.pushNotificationMultisigApprovalTitle(
            params.signatory,
            preferredLanguages: locale.rLanguages
        )
    }

    override func createBody(
        using payload: MultisigPayloadProtocol,
        params: MultisigNotificationParams
    ) -> String {
        guard let approvals = payload.approvals else { return "" }

        return R.string.localizable.pushNotificationMultisigApprovalBody(
            approvals,
            params.multisigAccount.threshold,
            preferredLanguages: locale.rLanguages
        )
    }
}
