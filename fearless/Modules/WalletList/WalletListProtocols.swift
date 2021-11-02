import Foundation
import RobinHood
import SubstrateSdk

protocol WalletListViewProtocol: ControllerBackedProtocol {}

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
    func didReceive(state: WebSocketEngine.State, for chainId: ChainModel.Id)
}

protocol WalletListWireframeProtocol: AnyObject {}
