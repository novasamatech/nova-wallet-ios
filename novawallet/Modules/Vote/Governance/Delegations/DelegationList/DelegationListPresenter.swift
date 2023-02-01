import Foundation

final class DelegationListPresenter {
    weak var view: DelegationListViewProtocol?
    let wireframe: DelegationListWireframeProtocol
    let interactor: DelegationListInteractorInputProtocol

    init(
        interactor: DelegationListInteractorInputProtocol,
        wireframe: DelegationListWireframeProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
    }
}

extension DelegationListPresenter: DelegationListPresenterProtocol {
    func setup() {
        interactor.setup()
    }
}

extension DelegationListPresenter: DelegationListInteractorOutputProtocol {
    func didReceive(delegations _: [AccountAddress: [GovernanceOffchainDelegation]]) {}

    func didReceive(error _: DelegationListError) {}
}
