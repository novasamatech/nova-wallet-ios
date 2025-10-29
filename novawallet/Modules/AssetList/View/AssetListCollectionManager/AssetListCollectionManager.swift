import UIKit

final class AssetListCollectionManager {
    weak var delegate: AssetListCollectionManagerDelegate?

    var collectionViewLayout: AssetListFlowLayout? {
        viewController?.rootView.collectionViewLayout
    }

    weak var viewController: AssetListViewController?

    private var groupsViewModel: AssetListViewModel

    private let collectionViewDataSource: AssetListCollectionViewDataSource
    // swiftlint:disable:next weak_delegate
    private let collectionViewDelegate: AssetListCollectionViewDelegate

    init(
        viewController: AssetListViewController,
        bannersViewProvider: BannersViewProviderProtocol,
        groupsViewModel: AssetListViewModel,
        delegate: AssetListCollectionManagerDelegate? = nil,
        selectedLocale: Locale
    ) {
        self.groupsViewModel = groupsViewModel
        self.viewController = viewController
        self.delegate = delegate

        collectionViewDataSource = AssetListCollectionViewDataSource(
            view: viewController,
            bannersViewProvider: bannersViewProvider,
            groupsViewModel: groupsViewModel,
            selectedLocale: selectedLocale
        )

        collectionViewDelegate = AssetListCollectionViewDelegate(
            bannersViewProvider: bannersViewProvider,
            groupsViewModel: groupsViewModel
        )

        setup()
    }

    private func setup() {
        collectionViewDataSource.groupsLayoutDelegate = self
        collectionViewDataSource.actionsDelegate = delegate
        collectionViewDelegate.selectionDelegate = self
        collectionViewDelegate.groupsLayoutDelegate = self

        viewController?.rootView.collectionView.dataSource = collectionViewDataSource
        viewController?.rootView.collectionView.delegate = collectionViewDelegate

        viewController?.rootView.collectionView.refreshControl?.addTarget(
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
        collectionViewLayout?.animatingTransition = true
    }

    func endLayoutTransition() {
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
        viewController?.rootView.collectionView.registerCellClass(AssetListTokenGroupAssetCell.self)
        viewController?.rootView.collectionView.registerCellClass(AssetListNetworkGroupAssetCell.self)
        viewController?.rootView.collectionView.registerCellClass(AssetListTotalBalanceCell.self)
        viewController?.rootView.collectionView.registerCellClass(AssetListAccountCell.self)
        viewController?.rootView.collectionView.registerCellClass(AssetListSettingsCell.self)
        viewController?.rootView.collectionView.registerCellClass(AssetListEmptyCell.self)
        viewController?.rootView.collectionView.registerCellClass(AssetListNftsCell.self)
        viewController?.rootView.collectionView.registerCellClass(AssetListMultisigOperationsCell.self)
        viewController?.rootView.collectionView.registerCellClass(BannersContainerCollectionViewCell.self)
        viewController?.rootView.collectionView.registerClass(
            AssetListNetworkView.self,
            forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader
        )

        collectionViewLayout?.register(
            AssetListOrganizerDecorationView.self,
            forDecorationViewOfKind: AssetListFlowLayout.DecorationIdentifiers.organizer
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
        from _: AssetListViewModel,
        to newViewModel: AssetListViewModel
    ) {
        guard let view = viewController?.rootView else { return }

        prepareForLayoutTransition()
        updateTokensGroupLayout()

        view.collectionViewLayout.changeGroupLayoutStyle(to: newViewModel.listGroupStyle)

        let removingIndexes = (0 ..< view.collectionView.numberOfSections).filter { section in
            section >= AssetListFlowLayout.SectionType.assetsStartingSection
        }

        let insertingIndexes = newViewModel.listState.groups.enumerated().map { index, _ in
            AssetListFlowLayout.SectionType.assetsStartingSection + index
        }

        replaceViewModel(newViewModel)

        view.collectionView.performBatchUpdates {
            view.collectionView.deleteSections(IndexSet(removingIndexes))
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

    func updateOrganizerViewModel(with model: AssetListOrganizerViewModel?) {
        collectionViewDataSource.organizerViewModel = model
    }

    func updateBanners(available: Bool) {
        collectionViewDataSource.bannersAvailable = available
    }

    func updateSelectedLocale(with locale: Locale) {
        collectionViewDataSource.selectedLocale = locale
    }

    func updateLoadingState() {
        viewController?.rootView.collectionView.visibleCells.forEach { updateLoadingState(for: $0) }
    }
}

// MARK: AssetListCollectionViewLayoutDelegate

extension AssetListCollectionManager: AssetListCollectionViewLayoutDelegate {
    func sectionInsets(for type: AssetListFlowLayout.SectionType, section: Int) -> UIEdgeInsets {
        viewController?.rootView.collectionViewLayout.sectionInsets(
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
        viewController?.rootView.collectionViewLayout.cellHeight(
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
    func selectOrganizerItem(at index: Int) {
        delegate?.selectOrganizerItem(at: index)
    }

    func selectAsset(for chainAssetId: ChainAssetId) {
        delegate?.selectAsset(for: chainAssetId)
    }
}
