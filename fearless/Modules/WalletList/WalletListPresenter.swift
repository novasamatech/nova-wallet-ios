import Foundation
import RobinHood

final class WalletListPresenter {
    weak var view: WalletListViewProtocol?
    let wireframe: WalletListWireframeProtocol
    let interactor: WalletListInteractorInputProtocol

    init(
        interactor: WalletListInteractorInputProtocol,
        wireframe: WalletListWireframeProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
    }
}

extension WalletListPresenter: WalletListPresenterProtocol {
    func setup() {}
}

extension WalletListPresenter: WalletListInteractorOutputProtocol {
    func didReceivePrices(result _: Result<[ChainModel.Id: PriceData], Error>) {}

    func didReceiveChainModelChanges(_: [DataProviderChange<ChainModel>]) {}

    func didReceiveAccountInfo(result _: Result<AccountInfo?, Error>, chainId _: ChainModel.Id) {}
}
