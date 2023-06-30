import Foundation
import RobinHood
import SubstrateSdk
import BigInt

protocol AssetListViewProtocol: ControllerBackedProtocol {
    func didReceiveHeader(viewModel: AssetListHeaderViewModel)
    func didReceiveGroups(state: AssetListGroupState)
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
    func presentWalletConnect()
}

protocol AssetListInteractorInputProtocol: AssetListBaseInteractorInputProtocol {
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
}

protocol AssetListWireframeProtocol: AnyObject, WalletSwitchPresentable, AlertPresentable, ErrorPresentable,
    CommonRetryable, WalletConnectScanPresentable, WalletConnectErrorPresentable {
    func showAssetDetails(from view: AssetListViewProtocol?, chain: ChainModel, asset: AssetModel)
    func showAssetsSettings(from view: AssetListViewProtocol?)
    func showTokensManage(from view: AssetListViewProtocol?)

    func showAssetsSearch(
        from view: AssetListViewProtocol?,
        initState: AssetListInitState,
        delegate: AssetsSearchDelegate
    )

    func showNfts(from view: AssetListViewProtocol?)

    func showBalanceBreakdown(
        from view: AssetListViewProtocol?,
        prices: [ChainAssetId: PriceData],
        balances: [AssetBalance],
        chains: [ChainModel.Id: ChainModel],
        locks: [AssetLock],
        crowdloans: [ChainModel.Id: [CrowdloanContributionData]]
    )

    func showWalletConnect(from view: AssetListViewProtocol?)

    func showRecieveTokens(
        from view: AssetListViewProtocol?,
        state: AssetListInitState
    )

    func showSendTokens(
        from view: AssetListViewProtocol?,
        state: AssetListInitState,
        transferCompletion: @escaping TransferCompletionClosure
    )

    func showBuyTokens(
        from view: AssetListViewProtocol?,
        state: AssetListInitState
    )
}

typealias WalletConnectSessionsError = WalletConnectSessionsInteractorError
typealias TransferCompletionClosure = (ChainAsset) -> Void
