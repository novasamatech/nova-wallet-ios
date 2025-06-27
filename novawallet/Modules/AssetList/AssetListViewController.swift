import UIKit
import Foundation_iOS

final class AssetListViewController: UIViewController, ViewHolder {
    typealias RootViewType = AssetListViewLayout

    let presenter: AssetListPresenterProtocol
    let bannersViewProvider: BannersViewProviderProtocol

    var collectionViewLayout: UICollectionViewFlowLayout? {
        rootView.collectionView.collectionViewLayout as? UICollectionViewFlowLayout
    }

    private lazy var collectionViewManager: AssetListCollectionManagerProtocol = {
        AssetListCollectionManager(
            viewController: self,
            bannersViewProvider: bannersViewProvider,
            groupsViewModel: groupsViewModel,
            delegate: self,
            selectedLocale: selectedLocale
        )
    }()

    private var groupsViewModel: AssetListViewModel = .init(
        isFiltered: false,
        listState: .list(groups: []),
        listGroupStyle: .tokens
    )

    init(
        presenter: AssetListPresenterProtocol,
        bannersViewProvider: BannersViewProviderProtocol,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.presenter = presenter
        self.bannersViewProvider = bannersViewProvider

        super.init(nibName: nil, bundle: nil)

        self.localizationManager = localizationManager
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = AssetListViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupCollectionView()
        presenter.setup()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        collectionViewManager.updateLoadingState()
    }

    private func setupCollectionView() {
        collectionViewManager.setupCollectionView()
    }

    func updateTotalBalanceHeight(_ height: CGFloat) {
        rootView.collectionViewLayout.updateTotalBalanceHeight(height)
    }

    private func activatePromotionWithHeight(_ height: CGFloat) {
        rootView.collectionViewLayout.activatePromotionWithHeight(height)
    }

    private func deactivatePromotion() {
        rootView.collectionViewLayout.deactivatePromotion()
    }

    private func setNftsActive(_ isActive: Bool) {
        rootView.collectionViewLayout.setNftsActive(isActive)
    }
}

// MARK: AssetListViewProtocol

extension AssetListViewController: AssetListViewProtocol {
    func didReceiveMultisigOperations(viewModel: AssetListMultisigOperationsViewModel?) {
        <#code#>
    }
    
    func didReceiveHeader(viewModel: AssetListHeaderViewModel) {
        collectionViewManager.updateHeaderViewModel(with: viewModel)

        rootView.collectionView.reloadData()

        let cellHeight = viewModel.locksAmount == nil ?
            AssetListMeasurement.totalBalanceHeight : AssetListMeasurement.totalBalanceWithLocksHeight

        updateTotalBalanceHeight(cellHeight)
    }

    func didReceiveGroups(viewModel: AssetListViewModel) {
        let oldViewModel = groupsViewModel
        let newViewModel = viewModel

        groupsViewModel = newViewModel

        collectionViewManager.updateGroupsViewModel(with: newViewModel)
        collectionViewManager.updateTokensGroupLayout()

        if oldViewModel.listGroupStyle != newViewModel.listGroupStyle {
            collectionViewManager.changeCollectionViewLayout(
                from: oldViewModel,
                to: newViewModel
            )
        } else {
            rootView.collectionView.reloadData()
        }
    }

    func didReceiveNft(viewModel: AssetListNftsViewModel?) {
        collectionViewManager.updateNftViewModel(with: viewModel)

        rootView.collectionView.reloadData()

        let isNftActive = viewModel != nil
        setNftsActive(isNftActive)
    }

    func didCompleteRefreshing() {
        rootView.collectionView.refreshControl?.endRefreshing()
    }

    func didReceiveBanners(available: Bool) {
        collectionViewManager.updateBanners(available: available)

        let height = bannersViewProvider.getMaxBannerHeight()

        if available {
            activatePromotionWithHeight(height)
        } else {
            deactivatePromotion()
        }

        rootView.collectionView.performBatchUpdates {
            self.rootView.collectionView.reloadSections(
                [AssetListFlowLayout.SectionType.banners.index]
            )
        }
    }

    func didReceiveAssetListStyle(_ style: AssetListGroupsStyle) {
        rootView.assetGroupsLayoutStyle = style
    }
}

// MARK: AssetListCollectionManagerDelegate

extension AssetListViewController: AssetListCollectionManagerDelegate {
    func selectAsset(for chainAssetId: ChainAssetId) {
        presenter.selectAsset(for: chainAssetId)
    }

    func selectNfts() {
        presenter.selectNfts()
    }

    func actionSelectAccount() {
        presenter.selectWallet()
    }

    func actionSelectWalletConnect() {
        presenter.presentWalletConnect()
    }

    func actionRefresh() {
        let nftIndexPath = AssetListFlowLayout.CellType.yourNfts.indexPath
        if let nftCell = rootView.collectionView.cellForItem(at: nftIndexPath) as? AssetListNftsCell {
            nftCell.refresh()
        }

        presenter.refresh()
    }

    func actionSearch() {
        presenter.presentSearch()
    }

    func actionManage() {
        presenter.presentAssetsManage()
    }

    func actionLocks() {
        presenter.presentLocks()
    }

    func actionSend() {
        presenter.send()
    }

    func actionReceive() {
        presenter.receive()
    }

    func actionBuySell() {
        presenter.buySell()
    }

    func actionSwap() {
        presenter.swap()
    }

    func actionCardOpen() {
        presenter.presentCard()
    }

    func actionChangeAssetListStyle() {
        presenter.toggleAssetListStyle()
    }
}

// MARK: Localizable

extension AssetListViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            collectionViewManager.updateSelectedLocale(with: selectedLocale)
            rootView.collectionView.reloadData()
        }
    }
}

// MARK: HiddableBarWhenPushed

extension AssetListViewController: HiddableBarWhenPushed {}
