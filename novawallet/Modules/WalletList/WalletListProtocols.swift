import Foundation
import RobinHood
import SubstrateSdk
import BigInt

protocol WalletListViewProtocol: ControllerBackedProtocol {
    func didReceiveHeader(viewModel: WalletListHeaderViewModel)
    func didReceiveGroups(state: WalletListGroupState)
    func didReceiveNft(viewModel: WalletListNftsViewModel?)
    func didCompleteRefreshing()
}

protocol WalletListPresenterProtocol: AnyObject {
    func setup()
    func selectWallet()
    func selectAsset(for chainAssetId: ChainAssetId)
    func selectNfts()
    func refresh()
    func presentSettings()
    func presentSearch()
}

protocol WalletListInteractorInputProtocol: WalletListBaseInteractorInputProtocol {
    func refresh()
}

protocol WalletListInteractorOutputProtocol: WalletListBaseInteractorOutputProtocol {
    func didReceive(genericAccountId: AccountId, name: String)
    func didReceiveNft(changes: [DataProviderChange<NftModel>])
    func didReceiveNft(error: Error)
    func didResetNftProvider()
    func didReceive(state: WebSocketEngine.State, for chainId: ChainModel.Id)
    func didChange(name: String)
    func didReceive(hidesZeroBalances: Bool)
}

protocol WalletListWireframeProtocol: AnyObject {
    func showWalletList(from view: WalletListViewProtocol?)
    func showAssetDetails(from view: WalletListViewProtocol?, chain: ChainModel, asset: AssetModel)
    func showAssetsManage(from view: WalletListViewProtocol?)
    func showAssetsSearch(from view: WalletListViewProtocol?, delegate: AssetsSearchDelegate)
    func showNfts(from view: WalletListViewProtocol?)
}
