import UIKit

class AssetsSearchCollectionViewDataSource: NSObject {
    var groupsViewModel: AssetListViewModel
    var headerViewModel: AssetListHeaderViewModel?

    var selectedLocale: Locale

    weak var groupsLayoutDelegate: AssetsSearchCollectionViewLayoutDelegate?

    init(
        groupsViewModel: AssetListViewModel,
        selectedLocale: Locale,
        groupsLayoutDelegate: AssetsSearchCollectionViewLayoutDelegate? = nil
    ) {
        self.groupsViewModel = groupsViewModel
        self.selectedLocale = selectedLocale
        self.groupsLayoutDelegate = groupsLayoutDelegate
    }

    func provideEmptyStateCell(
        _ collectionView: UICollectionView,
        indexPath: IndexPath
    ) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCellWithType(
            AssetListEmptyCell.self,
            for: indexPath
        )!

        let text = R.string(preferredLanguages: selectedLocale.rLanguages).localizable.assetsSearchEmpty()
        cell.view.bind(text: text)
        cell.actionButton.isHidden = true
        return cell
    }

    func emptyStateCellHeight(indexPath: IndexPath) -> CGFloat {
        AssetsSearchFlowLayout.CellType(indexPath: indexPath).height
    }
}

// MARK: Private

private extension AssetsSearchCollectionViewDataSource {
    func provideAssetCell(
        _ collectionView: UICollectionView,
        indexPath: IndexPath
    ) -> UICollectionViewCell {
        guard let groupIndex = AssetsSearchFlowLayout.SectionType.assetsGroupIndexFromSection(
            indexPath.section
        ) else {
            return UICollectionViewCell()
        }

        return switch groupsViewModel.listState.groups[groupIndex] {
        case let .network(groupViewModel):
            provideNetworkGroupAssetCell(
                collectionView,
                groupViewModel: groupViewModel,
                indexPath: indexPath
            )
        case let .token(groupViewModel):
            provideTokenGroupAssetCell(
                collectionView,
                groupViewModel: groupViewModel,
                indexPath: indexPath
            )
        }
    }

    func provideNetworkGroupAssetCell(
        _ collectionView: UICollectionView,
        groupViewModel: AssetListNetworkGroupViewModel,
        indexPath: IndexPath
    ) -> AssetListAssetCell {
        let assetCell = collectionView.dequeueReusableCellWithType(
            AssetListNetworkGroupAssetCell.self,
            for: indexPath
        )!

        assetCell.bind(viewModel: groupViewModel.assets[indexPath.row])

        return assetCell
    }

    func provideTokenGroupAssetCell(
        _ collectionView: UICollectionView,
        groupViewModel: AssetListTokenGroupViewModel,
        indexPath: IndexPath
    ) -> AssetListAssetCell {
        let expanded = groupsLayoutDelegate?.groupExpanded(
            for: groupViewModel.token.symbol
        ) ?? false

        let assetCell: AssetListAssetCell

        if expanded, indexPath.row != 0 {
            let cell = collectionView.dequeueReusableCellWithType(
                AssetListTokenGroupAssetCell.self,
                for: indexPath
            )!
            cell.bind(viewModel: groupViewModel.assets[indexPath.row - 1])

            assetCell = cell
        } else {
            let cell: AssetListAssetCell = collectionView.dequeueReusableCellWithType(
                AssetListNetworkGroupAssetCell.self,
                for: indexPath
            )!
            cell.bind(viewModel: groupViewModel)

            if expanded {
                cell.showDivider()
            }

            assetCell = cell
        }

        return assetCell
    }

    func numberOfItemsForAssetGroup(_ section: Int) -> Int {
        if let groupIndex = AssetsSearchFlowLayout.SectionType.assetsGroupIndexFromSection(section) {
            switch groupsViewModel.listState.groups[groupIndex] {
            case let .network(groupViewModel):
                return groupViewModel.assets.count
            case let .token(groupViewModel):
                let expanded = groupsLayoutDelegate?.groupExpanded(
                    for: groupViewModel.token.symbol
                ) ?? false

                return expanded
                    ? groupViewModel.assets.count + 1
                    : 1
            }
        } else {
            return 0
        }
    }
}

// MARK: UICollectionViewDataSource

extension AssetsSearchCollectionViewDataSource: UICollectionViewDataSource {
    func numberOfSections(in _: UICollectionView) -> Int {
        AssetsSearchFlowLayout.SectionType.assetsStartingSection + groupsViewModel.listState.groups.count
    }

    func collectionView(
        _: UICollectionView,
        numberOfItemsInSection section: Int
    ) -> Int {
        switch AssetsSearchFlowLayout.SectionType(section: section) {
        case .technical:
            groupsViewModel.listState.isEmpty ? 1 : 0
        case .assetGroup:
            numberOfItemsForAssetGroup(section)
        }
    }

    func collectionView(
        _ collectionView: UICollectionView,
        cellForItemAt indexPath: IndexPath
    ) -> UICollectionViewCell {
        switch AssetsSearchFlowLayout.CellType(indexPath: indexPath) {
        case .emptyState:
            provideEmptyStateCell(collectionView, indexPath: indexPath)
        case .asset:
            provideAssetCell(collectionView, indexPath: indexPath)
        }
    }

    func collectionView(
        _ collectionView: UICollectionView,
        viewForSupplementaryElementOfKind kind: String,
        at indexPath: IndexPath
    ) -> UICollectionReusableView {
        guard kind == UICollectionView.elementKindSectionHeader else {
            return UICollectionReusableView()
        }

        // Dequeue the header view
        let view = collectionView.dequeueReusableSupplementaryViewWithType(
            AssetListNetworkView.self,
            forSupplementaryViewOfKind: kind,
            for: indexPath
        )!

        // Configure the header view with the appropriate view model
        if let groupIndex = AssetsSearchFlowLayout.SectionType.assetsGroupIndexFromSection(indexPath.section),
           groupsViewModel.listGroupStyle == .networks,
           case let .network(viewModel) = groupsViewModel.listState.groups[groupIndex] {
            view.bind(viewModel: viewModel)
        }

        return view
    }
}
