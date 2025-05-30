import Foundation

final class GenericLedgerAddEvmPresenter {
    weak var view: GenericLedgerAccountSelectionViewProtocol?
    let wireframe: GenericLedgerAddEvmWireframeProtocol
    let interactor: GenericLedgerAddEvmInteractorInputProtocol

    init(
        interactor: GenericLedgerAddEvmInteractorInputProtocol,
        wireframe: GenericLedgerAddEvmWireframeProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
    }
}

extension GenericLedgerAddEvmPresenter: GenericLedgerAccountSelectionPresenterProtocol {
    func setup() {}

    func selectAccount(in _: Int) {}

    func selectAddress(in _: Int, at _: Int) {}

    func loadNext() {}
}

extension GenericLedgerAddEvmPresenter: GenericLedgerAddEvmInteractorOutputProtocol {
    func didReceive(account: GenericLedgerAccountModel) {
        
    }
    
    func didUpdateWallet() {
        
    }
    
    func didReceive(error: GenericLedgerAddEvmInteractorError) {
        
    }
}
