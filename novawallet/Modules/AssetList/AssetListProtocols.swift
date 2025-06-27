import Foundation
import Operation_iOS
import SubstrateSdk
import BigInt

// MARK: AssetListCollectionManager

protocol AssetListCollectionManagerProtocol {
    var delegate: AssetListCollectionManagerDelegate? { get set }

    func setupCollectionView()
    func updateGroupsViewModel(with model: AssetListViewModel)
    func updateHeaderViewModel(with model: AssetListHeaderViewModel?)
    func updateNftViewModel(with model: AssetListNftsViewModel?)
    func updateBanners(available: Bool)
    func updateSelectedLocale(with locale: Locale)

    func updateTokensGroupLayout()
    func changeCollectionViewLayout(
        from oldViewModel: AssetListViewModel,
        to newViewModel: AssetListViewModel
    )
    func updateLoadingState()
}

typealias AssetListCollectionManagerDelegate = AssetListCollectionViewActionsDelegate
    & AssetListCollectionSelectionDelegate

protocol AssetListCollectionViewActionsDelegate: AnyObject {
    func actionSelectAccount()
    func actionSearch()
    func actionRefresh()
    func actionManage()
    func actionSelectWalletConnect()
    func actionLocks()
    func actionSend()
    func actionReceive()
    func actionBuySell()
    func actionSwap()
    func actionChangeAssetListStyle()
    func actionCardOpen()
}

protocol AssetListCollectionSelectionDelegate: AnyObject {
    func selectAsset(for chainAssetId: ChainAssetId)
    func selectNfts()
}

protocol AssetListCollectionViewLayoutDelegate: AnyObject {
    func groupExpanded(for symbol: String) -> Bool
    func groupExpandable(for symbol: String) -> Bool
    func expandAssetGroup(for symbol: String)
    func collapseAssetGroup(for symbol: String)
    func sectionInsets(
        for type: AssetListFlowLayout.SectionType,
        section: Int
    ) -> UIEdgeInsets
    func cellHeight(
        for type: AssetListFlowLayout.CellType,
        at indexPath: IndexPath
    ) -> CGFloat
}

// MARK: View

protocol AssetListViewProtocol: ControllerBackedProtocol {
    func didReceiveHeader(viewModel: AssetListHeaderViewModel)
    func didReceiveGroups(viewModel: AssetListViewModel)
    func didReceiveNft(viewModel: AssetListNftsViewModel?)
    func didReceiveMultisigOperations(viewModel: AssetListMultisigOperationsViewModel?)
    func didReceiveBanners(available: Bool)
    func didCompleteRefreshing()
    func didReceiveAssetListStyle(_ style: AssetListGroupsStyle)
}

// MARK: Presenter

protocol AssetListPresenterProtocol: AnyObject {
    func setup()
    func selectWallet()
    func selectAsset(for chainAssetId: ChainAssetId)
    func selectNfts()
    func refresh()
    func presentSearch()
    func presentAssetsManage()
    func presentLocks()
    func presentCard()
    func send()
    func receive()
    func buySell()
    func swap()
    func presentWalletConnect()
    func toggleAssetListStyle()
}

// MARK: Interactor

protocol AssetListInteractorInputProtocol {
    func setup()
    func getFullChain(for chainId: ChainModel.Id) -> ChainModel?
    func refresh()
    func connectWalletConnect(uri: String)
    func retryFetchWalletConnectSessionsCount()
    func setAssetListGroupsStyle(_ style: AssetListGroupsStyle)
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
    func didReceiveWalletsState(hasUpdates: Bool)
    func didReceiveAssetListGroupStyle(_ style: AssetListGroupsStyle)
}

// MARK: Wireframe

protocol AssetListWireframeProtocol: AnyObject,
    WalletSwitchPresentable,
    AlertPresentable,
    ErrorPresentable,
    CommonRetryable,
    WalletConnectScanPresentable,
    WalletConnectErrorPresentable,
    RampActionsPresentable,
    RampPresentable {
    func showAssetDetails(from view: AssetListViewProtocol?, chain: ChainModel, asset: AssetModel)
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

    func showRamp(
        from view: (any AssetListViewProtocol)?,
        action: RampActionType,
        delegate: RampFlowStartingDelegate?
    )

    func showSwapTokens(from view: AssetListViewProtocol?)

    func showStaking(from view: AssetListViewProtocol?)

    func showCard(from view: AssetListViewProtocol?)

    func dropModalFlow(
        from view: AssetListViewProtocol?,
        completion: @escaping () -> Void
    )
}

typealias WalletConnectSessionsError = WalletConnectSessionsInteractorError
typealias TransferCompletionClosure = (ChainAsset) -> Void
typealias BuyTokensClosure = () -> Void
typealias SwapCompletionClosure = (ChainAsset) -> Void
