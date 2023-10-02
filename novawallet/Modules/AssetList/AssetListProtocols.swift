import Foundation
import RobinHood
import SubstrateSdk
import BigInt

protocol AssetListViewProtocol: ControllerBackedProtocol {
    func didReceiveHeader(viewModel: AssetListHeaderViewModel)
    func didReceiveGroups(viewModel: AssetListViewModel)
    func didReceiveNft(viewModel: AssetListNftsViewModel?)
    func didCompleteRefreshing()
}

protocol AssetListPresenterProtocol: AnyObject {
    func setup()
    func selectWallet()
    func selectAsset(for chainAssetId: ChainAssetId)
    func selectNfts()
    func refresh()
    func presentSettings()
    func presentSearch()
    func presentAssetsManage()
    func presentLocks()
    func send()
    func receive()
    func buy()
    func swap()
    func presentWalletConnect()
}

protocol AssetListInteractorInputProtocol {
    func setup()
    func getFullChain(for chainId: ChainModel.Id) -> ChainModel?
    func refresh()
    func connectWalletConnect(uri: String)
    func retryFetchWalletConnectSessionsCount()
}

protocol AssetListInteractorOutputProtocol {
    func didReceive(
        walletId: MetaAccountModel.Id,
        walletIdenticon: Data?,
        walletType: MetaAccountModelType,
        name: String
    )

    func didChange(name: String)
    func didReceive(hidesZeroBalances: Bool)
    func didReceive(result: AssetListBuilderResult)
    func didReceiveWalletConnect(sessionsCount: Int)
    func didReceiveWalletConnect(error: WalletConnectSessionsError)
    func didCompleteRefreshing()
}

protocol AssetListWireframeProtocol: AnyObject, WalletSwitchPresentable, AlertPresentable, ErrorPresentable,
    CommonRetryable, WalletConnectScanPresentable, WalletConnectErrorPresentable {
    func showAssetDetails(from view: AssetListViewProtocol?, chain: ChainModel, asset: AssetModel)
    func showAssetsSettings(from view: AssetListViewProtocol?)
    func showTokensManage(from view: AssetListViewProtocol?)

    func showAssetsSearch(from view: AssetListViewProtocol?, delegate: AssetsSearchDelegate)

    func showNfts(from view: AssetListViewProtocol?)

    func showBalanceBreakdown(from view: AssetListViewProtocol?, params: LocksViewInput)

    func showWalletConnect(from view: AssetListViewProtocol?)

    func showRecieveTokens(from view: AssetListViewProtocol?)

    func showSendTokens(
        from view: AssetListViewProtocol?,
        transferCompletion: @escaping TransferCompletionClosure,
        buyTokensClosure: @escaping BuyTokensClosure
    )

    func showBuyTokens(from view: AssetListViewProtocol?)

    func showSwapTokens(from view: AssetListViewProtocol?)
}

typealias WalletConnectSessionsError = WalletConnectSessionsInteractorError
typealias TransferCompletionClosure = (ChainAsset) -> Void
typealias BuyTokensClosure = () -> Void
