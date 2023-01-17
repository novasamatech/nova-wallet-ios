import Foundation

final class AddDelegationPresenter {
    weak var view: AddDelegationViewProtocol?
    let wireframe: AddDelegationWireframeProtocol
    let interactor: AddDelegationInteractorInputProtocol

    init(
        interactor: AddDelegationInteractorInputProtocol,
        wireframe: AddDelegationWireframeProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
    }
    
}

extension AddDelegationPresenter: AddDelegationPresenterProtocol {
    func setup() {}

    func selectDelegate(_: DelegateTableViewCell.Model) {}

    func closeBanner() {}

    func showAddDelegateInformation() {}

    func showSortOptions() {}

    func showFilters() {
        
    }
}

extension AddDelegationPresenter: AddDelegationInteractorOutputProtocol {
    
    func didReceive(delegators: Any) {
        
    }
    
}
