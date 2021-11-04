import Foundation
import RobinHood
import SubstrateSdk

protocol WalletListViewProtocol: ControllerBackedProtocol {
    func didReceiveHeader(viewModel: WalletListHeaderViewModel)
    func didReceiveAssets(viewModel: [WalletListViewModel])
}

protocol WalletListPresenterProtocol: AnyObject {
    func setup()
    func selectWallet()
}

protocol WalletListInteractorInputProtocol: AnyObject {
    func setup()
}

protocol WalletListInteractorOutputProtocol: AnyObject {
    func didReceive(genericAccountId: AccountId, name: String)
    func didReceiveChainModelChanges(_ changes: [DataProviderChange<ChainModel>])
    func didReceiveAccountInfo(result: Result<AccountInfo?, Error>, chainId: ChainModel.Id)
    func didReceivePrices(result: Result<[ChainModel.Id: PriceData], Error>)
    func didReceive(state: WebSocketEngine.State, for chainId: ChainModel.Id)
}

protocol WalletListWireframeProtocol: AnyObject {
    func showWalletList(from view: WalletListViewProtocol?)
}
