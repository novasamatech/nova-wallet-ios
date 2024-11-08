import UIKit
import SoraFoundation

final class AssetListViewController: UIViewController, ViewHolder {
    typealias RootViewType = AssetListViewLayout

    let presenter: AssetListPresenterProtocol

    var collectionViewLayout: UICollectionViewFlowLayout? {
        rootView.collectionView.collectionViewLayout as? UICollectionViewFlowLayout
    }

    private lazy var collectionViewManager: AssetListCollectionManagerProtocol = {
        AssetListCollectionManager(
            view: rootView,
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
        localizationManager: LocalizationManagerProtocol
    ) {
        self.presenter = presenter

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

        if oldViewModel.listGroupStyle != newViewModel.listGroupStyle {
            collectionViewManager.changeCollectionViewLayout(
                from: oldViewModel,
                to: newViewModel
            )
        } else {
            collectionViewManager.updateTokensGroupLayout()
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

    func didReceivePromotion(viewModel: PromotionBannerView.ViewModel) {
        collectionViewManager.updatePromotionBannerViewModel(with: viewModel)

        rootView.collectionView.reloadData()

        let height = AssetListBannerCell.estimateHeight(for: viewModel)
        activatePromotionWithHeight(height)
    }

    func didClosePromotion() {
        guard collectionViewManager.ableToClosePromotion else {
            return
        }

        rootView.collectionView.performBatchUpdates { [weak self] in
            self?.collectionViewManager.updatePromotionBannerViewModel(with: nil)

            let indexPath = AssetListFlowLayout.CellType.banner.indexPath
            self?.rootView.collectionView.deleteItems(at: [indexPath])
        }

        deactivatePromotion()
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

    func selectPromotion() {
        presenter.selectPromotion()
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

    func actionBuy() {
        presenter.buy()
    }

    func actionSwap() {
        presenter.swap()
    }

    func actionChangeAssetListStyle() {
        presenter.toggleAssetListStyle()
    }

    func promotionBannerDidRequestClose(view _: PromotionBannerView) {
        presenter.closePromotion()
    }
}

// MARK: Localizable

extension AssetListViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            rootView.collectionView.reloadData()
        }
    }
}

// MARK: HiddableBarWhenPushed

extension AssetListViewController: HiddableBarWhenPushed {}
