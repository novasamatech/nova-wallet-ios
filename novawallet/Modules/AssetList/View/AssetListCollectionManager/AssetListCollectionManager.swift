import UIKit

final class AssetListCollectionManager {
    weak var delegate: AssetListCollectionManagerDelegate?

    var ableToClosePromotion: Bool {
        promotionBannerViewModel != nil
    }

    var tokenGroupsLayout: AssetListTokensFlowLayout? {
        view?.collectionTokenGroupsLayout
    }

    var networkGroupsLayout: AssetListNetworksFlowLayout? {
        view?.collectionNetworkGroupsLayout
    }

    weak var view: AssetListViewLayout?

    private var groupsViewModel: AssetListViewModel
    private var promotionBannerViewModel: PromotionBannerView.ViewModel?

    private let collectionViewDataSource: AssetListCollectionViewDataSource
    private let collectionViewDelegate: AssetListCollectionViewDelegate

    init(
        view: AssetListViewLayout,
        groupsViewModel: AssetListViewModel,
        delegate: AssetListCollectionManagerDelegate? = nil,
        selectedLocale: Locale
    ) {
        self.groupsViewModel = groupsViewModel
        self.view = view
        self.delegate = delegate

        collectionViewDataSource = AssetListCollectionViewDataSource(
            groupsViewModel: groupsViewModel,
            selectedLocale: selectedLocale
        )

        collectionViewDelegate = AssetListCollectionViewDelegate(
            groupsViewModel: groupsViewModel
        )

        setup()
    }

    private func setup() {
        collectionViewDataSource.groupsLayoutDelegate = self
        collectionViewDataSource.actionsDelegate = delegate
        collectionViewDelegate.selectionDelegate = self
        collectionViewDelegate.groupsLayoutDelegate = self

        view?.collectionView.dataSource = collectionViewDataSource
        view?.collectionView.delegate = collectionViewDelegate

        view?.collectionView.refreshControl?.addTarget(
            self,
            action: #selector(actionRefresh),
            for: .valueChanged
        )
    }

    @objc private func actionRefresh() {
        delegate?.actionRefresh()
    }

    private func updateLoadingState(for cell: UICollectionViewCell) {
        (cell as? AnimationUpdatibleView)?.updateLayerAnimationIfActive()
    }
}

// MARK: AssetListCollectionManagerPtotocol

extension AssetListCollectionManager: AssetListCollectionManagerProtocol {
    func setupCollectionView() {
        view?.collectionView.registerCellClass(AssetListTokenGroupAssetCell.self)
        view?.collectionView.registerCellClass(AssetListNetworkGroupAssetCell.self)
        view?.collectionView.registerCellClass(AssetListTotalBalanceCell.self)
        view?.collectionView.registerCellClass(AssetListAccountCell.self)
        view?.collectionView.registerCellClass(AssetListSettingsCell.self)
        view?.collectionView.registerCellClass(AssetListEmptyCell.self)
        view?.collectionView.registerCellClass(AssetListNftsCell.self)
        view?.collectionView.registerCellClass(AssetListBannerCell.self)
        view?.collectionView.registerClass(
            AssetListNetworkView.self,
            forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader
        )

        networkGroupsLayout?.register(
            AssetListNetworkGroupDecorationView.self,
            forDecorationViewOfKind: AssetListNetworksFlowLayout.assetGroupDecoration
        )

        tokenGroupsLayout?.register(
            AssetListTokenGroupDecorationView.self,
            forDecorationViewOfKind: AssetListTokensFlowLayout.assetGroupDecoration
        )
    }

    func changeCollectionViewLayout(to style: AssetListGroupsStyle) {
        guard let view else { return }

        view.assetGroupsLayoutStyle = style

        let layout: UICollectionViewLayout = view.collectionViewLayout

        view.collectionView.setCollectionViewLayout(
            layout,
            animated: true
        )

        layout.invalidateLayout()
    }

    func updateTokensGroupLayout() {
        guard
            let tokenGroupsLayout,
            groupsViewModel.listGroupStyle == .tokens
        else {
            return
        }

        groupsViewModel.listState.groups.enumerated().forEach { groupIndex, group in
            guard case let .token(groupViewModel) = group else {
                return
            }

            let sectionIndex = tokenGroupsLayout.assetSectionIndex(from: groupIndex)

            tokenGroupsLayout.changeSection(
                byChanging: sectionIndex,
                for: groupViewModel.token.symbol
            )

            tokenGroupsLayout.setExpandableSection(
                for: groupViewModel.token.symbol,
                groupViewModel.assets.count > 1
            )
        }
    }

    func updateGroupsViewModel(with model: AssetListViewModel) {
        groupsViewModel = model

        collectionViewDataSource.groupsViewModel = model
        collectionViewDelegate.groupsViewModel = model
    }

    func updateHeaderViewModel(with model: AssetListHeaderViewModel?) {
        collectionViewDataSource.headerViewModel = model
    }

    func updateNftViewModel(with model: AssetListNftsViewModel?) {
        collectionViewDataSource.nftViewModel = model
    }

    func updatePromotionBannerViewModel(with model: PromotionBannerView.ViewModel?) {
        promotionBannerViewModel = model
        collectionViewDataSource.promotionBannerViewModel = model
    }

    func updateSelectedLocale(with locale: Locale) {
        collectionViewDataSource.selectedLocale = locale
    }

    func updateLoadingState() {
        view?.collectionView.visibleCells.forEach { updateLoadingState(for: $0) }
    }
}

// MARK: AssetListCollectionViewLayoutDelegate

extension AssetListCollectionManager: AssetListCollectionViewLayoutDelegate {
    func sectionInsets(for type: AssetListFlowLayout.SectionType, section: Int) -> UIEdgeInsets {
        view?.collectionViewLayout.sectionInsets(
            for: type,
            section: section
        ) ?? .zero
    }

    func groupExpandable(for symbol: String) -> Bool {
        tokenGroupsLayout?.state(for: symbol)?.expandable ?? false
    }

    func expandAssetGroup(for symbol: String) {
        tokenGroupsLayout?.expandAssetGroup(for: symbol)
    }

    func collapseAssetGroup(for symbol: String) {
        tokenGroupsLayout?.collapseAssetGroup(for: symbol)
    }

    func cellHeight(for type: AssetListFlowLayout.CellType, at indexPath: IndexPath) -> CGFloat {
        view?.collectionViewLayout.cellHeight(
            for: type,
            at: indexPath
        ) ?? .zero
    }

    func groupExpanded(for symbol: String) -> Bool {
        tokenGroupsLayout?.expanded(for: symbol) ?? false
    }
}

// MARK: AssetListCollectionSelectionDelegate

extension AssetListCollectionManager: AssetListCollectionSelectionDelegate {
    func selectAsset(for chainAssetId: ChainAssetId) {
        delegate?.selectAsset(for: chainAssetId)
    }

    func selectNfts() {
        delegate?.selectNfts()
    }

    func selectPromotion() {
        delegate?.selectPromotion()
    }
}