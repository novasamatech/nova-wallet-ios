import Foundation
import RobinHood

protocol WalletListViewProtocol: AnyObject {}

protocol WalletListPresenterProtocol: AnyObject {
    func setup()
}

protocol WalletListInteractorInputProtocol: AnyObject {
    func setup()
}

protocol WalletListInteractorOutputProtocol: AnyObject {
    func didReceiveChainModelChanges(_ changes: [DataProviderChange<ChainModel>])
    func didReceiveAccountInfo(result: Result<AccountInfo?, Error>, chainId: ChainModel.Id)
    func didReceivePrices(result: Result<[ChainModel.Id: PriceData], Error>)
}

protocol WalletListWireframeProtocol: AnyObject {}
