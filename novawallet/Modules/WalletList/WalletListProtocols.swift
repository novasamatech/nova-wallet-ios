import Foundation
import RobinHood
import SubstrateSdk
import BigInt

protocol WalletListViewProtocol: ControllerBackedProtocol {
    func didReceiveHeader(viewModel: WalletListHeaderViewModel)
    func didReceiveGroups(viewModels: [WalletListGroupViewModel])
    func didCompleteRefreshing()
}

protocol WalletListPresenterProtocol: AnyObject {
    func setup()
    func selectWallet()
    func selectAsset(at index: Int, in group: Int)
    func refresh()
}

protocol WalletListInteractorInputProtocol: AnyObject {
    func setup()
    func refresh()
}

protocol WalletListInteractorOutputProtocol: AnyObject {
    func didReceive(genericAccountId: AccountId, name: String)
    func didReceiveChainModelChanges(_ changes: [DataProviderChange<ChainModel>])
    func didReceiveBalance(result: Result<BigUInt, Error>, chainId: ChainModel.Id, assetId: AssetModel.Id)
    func didReceivePrices(result: Result<[ChainAssetId: PriceData], Error>?)
    func didReceive(state: WebSocketEngine.State, for chainId: ChainModel.Id)
    func didChange(name: String)
}

protocol WalletListWireframeProtocol: AnyObject {
    func showWalletList(from view: WalletListViewProtocol?)
    func showAssetDetails(from view: WalletListViewProtocol?, chain: ChainModel, asset: AssetModel)
}
