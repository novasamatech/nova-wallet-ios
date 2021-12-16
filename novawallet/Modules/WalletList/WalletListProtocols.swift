import Foundation
import RobinHood
import SubstrateSdk

protocol WalletListViewProtocol: ControllerBackedProtocol {
    func didReceiveHeader(viewModel: WalletListHeaderViewModel)
    func didReceiveAssets(viewModel: [WalletListViewModel])
    func didCompleteRefreshing()
}

protocol WalletListPresenterProtocol: AnyObject {
    func setup()
    func selectWallet()
    func selectAsset(at index: Int)
    func refresh()
}

protocol WalletListInteractorInputProtocol: AnyObject {
    func setup()
    func refresh()
}

protocol WalletListInteractorOutputProtocol: AnyObject {
    func didReceive(genericAccountId: AccountId, name: String)
    func didReceiveChainModelChanges(_ changes: [DataProviderChange<ChainModel>])
    func didReceiveAccountInfo(result: Result<AccountInfo?, Error>, chainId: ChainModel.Id)
    func didReceivePrices(result: Result<[ChainModel.Id: PriceData], Error>?)
    func didReceive(state: WebSocketEngine.State, for chainId: ChainModel.Id)
    func didChange(name: String)
}

protocol WalletListWireframeProtocol: AnyObject {
    func showWalletList(from view: WalletListViewProtocol?)
    func showAssetDetails(from view: WalletListViewProtocol?, chain: ChainModel)
}
