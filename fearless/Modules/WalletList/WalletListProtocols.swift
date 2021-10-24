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
    func didReceivePrice(result: Result<PriceData?, Error>, priceId: AssetModel.PriceId)
}

protocol WalletListWireframeProtocol: AnyObject {}
