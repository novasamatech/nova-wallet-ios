import Foundation

final class DelegatedSignConfirmationWireframe: DelegatedSignConfirmationWireframeProtocol {
    let delegatedAccountId: MetaAccountModel.Id
    let delegateAccountResponse: ChainAccountResponse
    let delegationType: DelegationType

    init(
        delegatedAccountId: MetaAccountModel.Id,
        delegateAccountResponse: ChainAccountResponse,
        delegationType: DelegationType
    ) {
        self.delegatedAccountId = delegatedAccountId
        self.delegateAccountResponse = delegateAccountResponse
        self.delegationType = delegationType
    }

    func showConfirmation(
        from view: ControllerBackedProtocol,
        completionClosure: @escaping DelegatedSignConfirmationCompletion
    ) {
        guard let delegatedConfirmationView = DelegatedMessageSheetViewFactory.createSigningView(
            delegatedId: delegatedAccountId,
            delegateChainAccountResponse: delegateAccountResponse,
            delegationType: delegationType,
            completionClosure: { completionClosure(true) },
            cancelClosure: { completionClosure(false) }
        ) else {
            completionClosure(false)
            return
        }

        view.controller.present(delegatedConfirmationView.controller, animated: true)
    }
}
