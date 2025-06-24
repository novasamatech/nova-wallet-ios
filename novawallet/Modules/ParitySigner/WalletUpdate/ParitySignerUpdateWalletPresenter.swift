import Foundation

final class ParitySignerUpdateWalletPresenter: HardwareWalletAddressesBasePresenter {
    let wireframe: ParitySignerUpdateWalletWireframeProtocol
    let interactor: ParitySignerUpdateWalletInteractorInputProtocol

    init(
        interactor: ParitySignerUpdateWalletInteractorInputProtocol,
        wireframe: ParitySignerUpdateWalletWireframeProtocol,
        viewModelFactory: ChainAccountViewModelFactoryProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe

        super.init(viewModelFactory: viewModelFactory)
    }
}

extension ParitySignerUpdateWalletPresenter: ParitySignerUpdateWalletPresenterProtocol {
    func setup() {}
}

extension ParitySignerUpdateWalletPresenter: ParitySignerUpdateWalletInteractorOutputProtocol {}
