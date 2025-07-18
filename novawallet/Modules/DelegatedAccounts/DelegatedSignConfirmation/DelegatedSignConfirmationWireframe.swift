import Foundation

final class DelegatedSignConfirmationWireframe: DelegatedSignConfirmationWireframeProtocol {
    let delegatedAccountId: MetaAccountModel.Id
    let delegateAccountResponse: ChainAccountResponse
    let delegationClass: DelegationClass

    init(
        delegatedAccountId: MetaAccountModel.Id,
        delegateAccountResponse: ChainAccountResponse,
        delegationClass: DelegationClass
    ) {
        self.delegatedAccountId = delegatedAccountId
        self.delegateAccountResponse = delegateAccountResponse
        self.delegationClass = delegationClass
    }

    func showConfirmation(
        from view: ControllerBackedProtocol,
        completionClosure: @escaping DelegatedSignConfirmationCompletion
    ) {
        guard let delegatedConfirmationView = DelegatedMessageSheetViewFactory.createSigningView(
            delegatedId: delegatedAccountId,
            delegateChainAccountResponse: delegateAccountResponse,
            delegationClass: delegationClass,
            completionClosure: { completionClosure(true) },
            cancelClosure: { completionClosure(false) }
        ) else {
            completionClosure(false)
            return
        }

        view.controller.present(delegatedConfirmationView.controller, animated: true)
    }
}
