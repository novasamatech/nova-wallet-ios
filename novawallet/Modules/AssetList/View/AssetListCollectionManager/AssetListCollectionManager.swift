import UIKit

final class AssetListCollectionManager {
    weak var delegate: AssetListCollectionManagerDelegate?

    var ableToClosePromotion: Bool {
        promotionBannerViewModel != nil
    }

    var collectionViewLayout: AssetListFlowLayout? {
        view?.collectionViewLayout
    }

    weak var view: AssetListViewLayout?

    private var groupsViewModel: AssetListViewModel
    private var promotionBannerViewModel: PromotionBannerView.ViewModel?

    private let collectionViewDataSource: AssetListCollectionViewDataSource
    private let collectionViewDelegate: AssetListCollectionViewDelegate

    private var transitingLayout: Bool = false

    private var pendingLayout: (old: AssetListViewModel, new: AssetListViewModel)?

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

    func prepareForLayoutTransition() {
        transitingLayout = true
        collectionViewLayout?.animatingTransition = true
    }

    func endLayoutTransition() {
        transitingLayout = false
        collectionViewLayout?.animatingTransition = false
    }

    private func replaceViewModel(_ newViewModel: AssetListViewModel) {
        groupsViewModel = newViewModel

        collectionViewDataSource.groupsViewModel = newViewModel
        collectionViewDelegate.groupsViewModel = newViewModel
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

        collectionViewLayout?.register(
            AssetListNetworkGroupDecorationView.self,
            forDecorationViewOfKind: AssetListFlowLayout.DecorationIdentifiers.networkGroup
        )

        collectionViewLayout?.register(
            AssetListTokenGroupDecorationView.self,
            forDecorationViewOfKind: AssetListFlowLayout.DecorationIdentifiers.tokenGroup
        )
    }

    func changeCollectionViewLayout(
        from oldViewModel: AssetListViewModel,
        to newViewModel: AssetListViewModel
    ) {
        guard let view else { return }

        prepareForLayoutTransition()
        updateTokensGroupLayout()

        view.collectionViewLayout.changeGroupLayoutStyle(to: newViewModel.listGroupStyle)

        let removingViewModel = AssetListViewModel(
            isFiltered: oldViewModel.isFiltered,
            listState: .list(groups: []),
            listGroupStyle: oldViewModel.listGroupStyle
        )

        let removingIndexes = (0 ..< view.collectionView.numberOfSections).filter { section in
            section >= AssetListFlowLayout.SectionType.assetsStartingSection
        }

        let insertingIndexes = newViewModel.listState.groups.enumerated().map { index, _ in
            AssetListFlowLayout.SectionType.assetsStartingSection + index
        }

        replaceViewModel(removingViewModel)

        view.collectionView.performBatchUpdates {
            view.collectionView.deleteSections(IndexSet(removingIndexes))
            replaceViewModel(newViewModel)
            view.collectionView.insertSections(IndexSet(insertingIndexes))
        } completion: { [weak self] _ in
            self?.endLayoutTransition()
        }
    }

    func updateTokensGroupLayout() {
        guard
            let collectionViewLayout,
            groupsViewModel.listGroupStyle == .tokens
        else {
            return
        }

        groupsViewModel.listState.groups.enumerated().forEach { groupIndex, group in
            guard case let .token(groupViewModel) = group else {
                return
            }

            let sectionIndex = collectionViewLayout.assetSectionIndex(from: groupIndex)

            collectionViewLayout.changeSection(
                byChanging: sectionIndex,
                for: groupViewModel.token.symbol
            )

            collectionViewLayout.setExpandableSection(
                for: groupViewModel.token.symbol,
                groupViewModel.assets.count > 1
            )
        }
    }

    func updateGroupsViewModel(with model: AssetListViewModel) {
        replaceViewModel(model)
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
        collectionViewLayout?.state(for: symbol)?.expandable ?? false
    }

    func expandAssetGroup(for symbol: String) {
        collectionViewLayout?.expandAssetGroup(for: symbol)
    }

    func collapseAssetGroup(for symbol: String) {
        collectionViewLayout?.collapseAssetGroup(for: symbol)
    }

    func cellHeight(for type: AssetListFlowLayout.CellType, at indexPath: IndexPath) -> CGFloat {
        view?.collectionViewLayout.cellHeight(
            for: type,
            at: indexPath
        ) ?? .zero
    }

    func groupExpanded(for symbol: String) -> Bool {
        collectionViewLayout?.expanded(for: symbol) ?? false
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
