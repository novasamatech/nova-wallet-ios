import Foundation
import UIKit
import Operation_iOS
import SubstrateSdk
import BigInt

// MARK: AssetListCollectionManager

protocol AssetListCollectionManagerProtocol {
    var delegate: AssetListCollectionManagerDelegate? { get set }

    func setupCollectionView()
    func updateAlertViewModel(with model: InlinableAlertView.Model?)
    func updateGroupsViewModel(with model: AssetListViewModel)
    func updateHeaderViewModel(with model: AssetListHeaderViewModel?)
    func updateOrganizerViewModel(with model: AssetListOrganizerViewModel?)
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
    func actionGift()
    func actionChangeAssetListStyle()
    func actionCardOpen()
    func actionTogglePrivacy()
    func actionAlertLearnMore(_ alertType: InlinableAlertView.Model.AlertType)
    func actionLoadMore()
}

protocol AssetListCollectionSelectionDelegate: AnyObject {
    func selectAsset(for chainAssetId: ChainAssetId)
    func selectOrganizerItem(at index: Int)
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
    func didReceiveFullUpdate(viewModel: AssetListFullUpdateViewModel)
    func didReceiveHeader(viewModel: AssetListHeaderViewModel)
    func didReceiveAlert(viewModel: InlinableAlertView.Model?)
    func didReceiveGroups(viewModel: AssetListViewModel)
    func didReceiveOrganizer(viewModel: AssetListOrganizerViewModel?)
    func didReceiveBanners(available: Bool)
    func didCompleteRefreshing()
    func didReceiveAssetListStyle(_ style: AssetListGroupsStyle)
}

// MARK: Presenter

protocol AssetListPresenterProtocol: AnyObject {
    func setup()
    func selectWallet()
    func selectOrganizerItem(at index: Int)
    func selectAsset(for chainAssetId: ChainAssetId)
    func refresh()
    func presentSearch()
    func presentAssetsManage()
    func presentLocks()
    func presentCard()
    func send()
    func receive()
    func buySell()
    func swap()
    func gift()
    func presentWalletConnect()
    func toggleAssetListStyle()
    func togglePrivacyMode()
    func presentLearnMore(_ alertType: InlinableAlertView.Model.AlertType)
    func presentLoadMoreTokens()
    func reloadAssets()
}

// MARK: Interactor

protocol AssetListInteractorInputProtocol {
    func setup()
    func getFullChain(for chainId: ChainModel.Id) -> ChainModel?
    func refresh()
    func connectWalletConnect(uri: String)
    func retryFetchWalletConnectSessionsCount()
    func setAssetListGroupsStyle(_ style: AssetListGroupsStyle)
    func markLoadMoreUsed()
    func hasUsedLoadMore() -> Bool
    func getUserAddedTokens() -> Set<ChainAssetId>
}

protocol AssetListInteractorOutputProtocol {
    func didReceive(wallet: MetaAccountModel)

    func didChange(name: String)
    func didReceive(hidesZeroBalances: Bool)
    func didReceive(dustFilterEnabled: Bool, threshold: Decimal)
    func didReceive(result: AssetListBuilderResult)
    func didReceiveWalletConnect(sessionsCount: Int)
    func didReceiveWalletConnect(error: WalletConnectSessionsError)
    func didCompleteRefreshing()
    func didReceiveWalletsState(hasUpdates: Bool)
    func didReceiveAssetListGroupStyle(_ style: AssetListGroupsStyle)
    func didReceive(defaultTokenIds: Set<ChainAssetId>?)
    func didReceive(userAddedTokenIds: Set<ChainAssetId>)
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
    RampPresentable,
    MessageSheetPresentable,
    FeatureSupportChecking,
    WebPresentable
{
    func showAssetDetails(from view: AssetListViewProtocol?, chainAsset: ChainAsset)
    func showTokensManage(from view: AssetListViewProtocol?)

    func showAssetsSearch(from view: AssetListViewProtocol?, delegate: AssetsSearchDelegate)

    func showNfts(from view: AssetListViewProtocol?)

    func showMultisigOperations(from view: AssetListViewProtocol?)

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

    func showGift(
        from view: AssetListViewProtocol?,
        chains: [ChainModel],
        selectedWallet: MetaAccountModel,
        transferCompletion: @escaping TransferCompletionClosure,
        buyTokensClosure: @escaping BuyTokensClosure
    )

    func showStaking(from view: AssetListViewProtocol?)

    func showCard(
        from view: AssetListViewProtocol?,
        wallet: MetaAccountModel
    )

    func dropModalFlow(
        from view: AssetListViewProtocol?,
        completion: @escaping () -> Void
    )

    func showLearnMore(
        from view: ControllerBackedProtocol?,
        for alertType: InlinableAlertView.Model.AlertType
    )
}

typealias WalletConnectSessionsError = WalletConnectSessionsInteractorError
typealias TransferCompletionClosure = (ChainAsset) -> Void
typealias BuyTokensClosure = () -> Void
typealias SwapCompletionClosure = (ChainAsset) -> Void
