import UIKit

final class AssetListCollectionViewDelegate: NSObject {
    let bannersViewProvider: BannersViewProviderProtocol

    var groupsViewModel: AssetListViewModel

    weak var selectionDelegate: AssetListCollectionSelectionDelegate?
    weak var groupsLayoutDelegate: AssetListCollectionViewLayoutDelegate?

    init(
        bannersViewProvider: BannersViewProviderProtocol,
        groupsViewModel: AssetListViewModel,
        selectionDelegate: AssetListCollectionSelectionDelegate? = nil,
        groupsLayoutDelegate: AssetListCollectionViewLayoutDelegate? = nil
    ) {
        self.bannersViewProvider = bannersViewProvider
        self.groupsViewModel = groupsViewModel
        self.selectionDelegate = selectionDelegate
        self.groupsLayoutDelegate = groupsLayoutDelegate
    }
}

// MARK: Private

private extension AssetListCollectionViewDelegate {
    func processAssetSelect(
        _ collectionView: UICollectionView,
        at indexPath: IndexPath
    ) {
        guard
            let groupsLayoutDelegate,
            let groupIndex = AssetListFlowLayout.SectionType.assetsGroupIndexFromSection(
                indexPath.section
            ) else {
            return
        }

        let groupViewModel = groupsViewModel.listState.groups[groupIndex]

        let chainAssetId: ChainAssetId

        switch groupViewModel {
        case let .network(group):
            chainAssetId = group.assets[indexPath.row].chainAssetId
        case let .token(group) where indexPath.row == 0:
            let symbol = group.token.symbol
            let expandable = groupsLayoutDelegate.groupExpandable(for: symbol)
            let expanded = groupsLayoutDelegate.groupExpanded(for: symbol)

            guard !expanded else {
                groupsLayoutDelegate.collapseAssetGroup(for: symbol)
                collectionView.reloadSections([indexPath.section])

                return
            }

            guard !expandable else {
                groupsLayoutDelegate.expandAssetGroup(for: symbol)
                collectionView.reloadSections([indexPath.section])

                return
            }

            chainAssetId = group.assets[indexPath.row].chainAssetId
        case let .token(group):
            let chainAssetIndex = indexPath.row - 1
            chainAssetId = group.assets[chainAssetIndex].chainAssetId
        }

        selectionDelegate?.selectAsset(for: chainAssetId)
    }
}

// MARK: Private helpers

private extension AssetListCollectionViewDelegate {
    var loadMoreSectionIndex: Int? {
        guard groupsViewModel.showsLoadMore else { return nil }
        return AssetListFlowLayout.SectionType.assetsStartingSection + groupsViewModel.listState.groups.count
    }
}

// MARK: UICollectionViewDelegateFlowLayout

extension AssetListCollectionViewDelegate: UICollectionViewDelegateFlowLayout {
    func collectionView(
        _ collectionView: UICollectionView,
        layout _: UICollectionViewLayout,
        sizeForItemAt indexPath: IndexPath
    ) -> CGSize {
        guard let groupsLayoutDelegate else { return .zero }

        let cellType = AssetListFlowLayout.CellType(
            indexPath: indexPath,
            in: collectionView,
            loadMoreSection: loadMoreSectionIndex
        )

        let cellHeight = groupsLayoutDelegate.cellHeight(
            for: cellType,
            at: indexPath
        )

        return CGSize(
            width: collectionView.bounds.width,
            height: cellHeight
        )
    }

    func collectionView(
        _ collectionView: UICollectionView,
        layout _: UICollectionViewLayout,
        referenceSizeForHeaderInSection section: Int
    ) -> CGSize {
        if section == loadMoreSectionIndex {
            return .zero
        }

        switch AssetListFlowLayout.SectionType(section: section) {
        case .assetGroup where groupsViewModel.listGroupStyle == .networks:
            return CGSize(
                width: collectionView.frame.width,
                height: AssetListMeasurement.assetHeaderHeight
            )
        case .summary, .settings, .organizer, .banners, .assetGroup:
            return CGSize.zero
        }
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)

        let cellType = AssetListFlowLayout.CellType(
            indexPath: indexPath,
            in: collectionView,
            loadMoreSection: loadMoreSectionIndex
        )

        switch cellType {
        case .account, .settings, .emptyState, .totalBalance, .banner, .alert, .loadMore:
            break
        case let .organizerItem(itemIndex: itemIndex):
            selectionDelegate?.selectOrganizerItem(at: itemIndex)
        case .asset:
            processAssetSelect(collectionView, at: indexPath)
        }
    }

    func collectionView(
        _: UICollectionView,
        layout _: UICollectionViewLayout,
        minimumLineSpacingForSectionAt section: Int
    ) -> CGFloat {
        if section == loadMoreSectionIndex {
            return 0
        }
        return AssetListFlowLayout.SectionType(section: section).cellSpacing
    }

    func collectionView(
        _: UICollectionView,
        layout _: UICollectionViewLayout,
        insetForSectionAt section: Int
    ) -> UIEdgeInsets {
        if section == loadMoreSectionIndex {
            return UIEdgeInsets(top: 8, left: 0, bottom: 16, right: 0)
        }

        let sectionType = AssetListFlowLayout.SectionType(section: section)

        return groupsLayoutDelegate?.sectionInsets(
            for: sectionType,
            section: section
        ) ?? .zero
    }
}
