import UIKit

class AssetsSearchCollectionManager {
    private weak var delegate: AssetsSearchCollectionManagerDelegate?

    var tokenGroupsLayout: AssetsSearchTokensFlowLayout? {
        view?.collectionTokenGroupsLayout
    }

    var networkGroupsLayout: AssetsSearchNetworksFlowLayout? {
        view?.collectionNetworkGroupsLayout
    }

    weak var view: BaseAssetsSearchViewLayout?

    var groupsViewModel: AssetListViewModel

    var collectionViewDataSource: AssetsSearchCollectionViewDataSource
    var collectionViewDelegate: AssetsSearchCollectionViewDelegate

    init(
        view: BaseAssetsSearchViewLayout,
        groupsViewModel: AssetListViewModel,
        delegate: AssetsSearchCollectionManagerDelegate?,
        selectedLocale: Locale
    ) {
        self.groupsViewModel = groupsViewModel
        self.view = view
        self.delegate = delegate

        collectionViewDataSource = AssetsSearchCollectionViewDataSource(
            groupsViewModel: groupsViewModel,
            selectedLocale: selectedLocale
        )

        collectionViewDelegate = AssetsSearchCollectionViewDelegate(
            groupsViewModel: groupsViewModel
        )

        setup()
    }

    func setup() {
        collectionViewDataSource.groupsLayoutDelegate = self
        collectionViewDelegate.selectionDelegate = self
        collectionViewDelegate.groupsLayoutDelegate = self

        view?.collectionView.dataSource = collectionViewDataSource
        view?.collectionView.delegate = collectionViewDelegate
    }

    func groupExpandable(for symbol: String) -> Bool {
        tokenGroupsLayout?.state(for: symbol)?.expandable ?? false
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

    func selectGroup(
        with symbol: AssetModel.Symbol,
        at indexPath: IndexPath
    ) {
        let expandable = groupExpandable(for: symbol)
        let expanded = groupExpanded(for: symbol)

        if expanded {
            collapseAssetGroup(for: symbol)
            view?.collectionView.reloadSections([indexPath.section])
        } else if expandable {
            expandAssetGroup(for: symbol)
            view?.collectionView.reloadSections([indexPath.section])
        } else {
            delegate?.selectGroup(with: symbol)
        }
    }

    private func updateLoadingState(for cell: UICollectionViewCell) {
        (cell as? AnimationUpdatibleView)?.updateLayerAnimationIfActive()
    }
}

// MARK: AssetListCollectionManagerPtotocol

extension AssetsSearchCollectionManager: AssetsSearchCollectionManagerProtocol {
    func setupCollectionView() {
        view?.collectionView.registerCellClass(AssetListTokenGroupAssetCell.self)
        view?.collectionView.registerCellClass(AssetListNetworkGroupAssetCell.self)
        view?.collectionView.registerCellClass(AssetListEmptyCell.self)
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
            animated: false
        )

        layout.invalidateLayout()
    }

    func updateGroupsViewModel(with model: AssetListViewModel) {
        groupsViewModel = model

        collectionViewDataSource.groupsViewModel = model
        collectionViewDelegate.groupsViewModel = model
    }

    func updateSelectedLocale(with locale: Locale) {
        collectionViewDataSource.selectedLocale = locale
    }

    func updateLoadingState() {
        view?.collectionView.visibleCells.forEach { updateLoadingState(for: $0) }
    }
}

// MARK: AssetListCollectionViewLayoutDelegate

extension AssetsSearchCollectionManager: AssetsSearchCollectionViewLayoutDelegate {
    func sectionInsets(for type: AssetsSearchFlowLayout.SectionType, section: Int) -> UIEdgeInsets {
        view?.collectionViewLayout.sectionInsets(
            for: type,
            section: section
        ) ?? .zero
    }

    func cellHeight(for type: AssetsSearchFlowLayout.CellType, at indexPath: IndexPath) -> CGFloat {
        view?.collectionViewLayout.cellHeight(
            for: type,
            at: indexPath
        ) ?? .zero
    }

    func expandAssetGroup(for symbol: String) {
        tokenGroupsLayout?.expandAssetGroup(for: symbol)
    }

    func collapseAssetGroup(for symbol: String) {
        tokenGroupsLayout?.collapseAssetGroup(for: symbol)
    }

    func groupExpanded(for symbol: String) -> Bool {
        tokenGroupsLayout?.expanded(for: symbol) ?? false
    }
}

// MARK: AssetListCollectionSelectionDelegate

extension AssetsSearchCollectionManager: AssetsSearchCollectionSelectionDelegate {
    func selectAsset(for chainAssetId: ChainAssetId) {
        delegate?.selectAsset(for: chainAssetId)
    }
}