import Foundation
import Operation_iOS
import SubstrateSdk
import BigInt

// MARK: AssetListCollectionManager

protocol AssetListCollectionManagerProtocol: ScrollViewHostProtocol {
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
    func actionSearch()
    func actionRefresh()
    func actionManage()
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
    func didReceiveBanners(available: Bool)
    func didCompleteRefreshing()
    func didReceiveAssetListStyle(_ style: AssetListGroupsStyle)
}

// MARK: Presenter

protocol AssetListPresenterProtocol: AnyObject {
    func setup()
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
    func toggleAssetListStyle()
}

// MARK: Interactor

protocol AssetListInteractorInputProtocol {
    func setup()
    func getFullChain(for chainId: ChainModel.Id) -> ChainModel?
    func refresh()
    func setAssetListGroupsStyle(_ style: AssetListGroupsStyle)
}

protocol AssetListInteractorOutputProtocol {
    func didReceive(walletId: String)
    func didReceive(hidesZeroBalances: Bool)
    func didReceive(result: AssetListBuilderResult)
    func didCompleteRefreshing()
    func didReceiveAssetListGroupStyle(_ style: AssetListGroupsStyle)
}

// MARK: Wireframe

protocol AssetListWireframeProtocol: AnyObject,
    AlertPresentable,
    ErrorPresentable,
    CommonRetryable,
    RampActionsPresentable,
    RampPresentable {
    func showAssetDetails(from view: AssetListViewProtocol?, chain: ChainModel, asset: AssetModel)
    func showTokensManage(from view: AssetListViewProtocol?)

    func showAssetsSearch(from view: AssetListViewProtocol?, delegate: AssetsSearchDelegate)

    func showNfts(from view: AssetListViewProtocol?)

    func showBalanceBreakdown(from view: AssetListViewProtocol?, params: LocksViewInput)

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

typealias TransferCompletionClosure = (ChainAsset) -> Void
typealias BuyTokensClosure = () -> Void
typealias SwapCompletionClosure = (ChainAsset) -> Void
