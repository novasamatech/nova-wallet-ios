import UIKit

final class AssetsSearchCollectionViewDelegate: NSObject {
    var groupsViewModel: AssetListViewModel

    weak var selectionDelegate: AssetsSearchCollectionSelectionDelegate?
    weak var groupsLayoutDelegate: AssetsSearchCollectionViewLayoutDelegate?

    init(
        groupsViewModel: AssetListViewModel,
        selectionDelegate: AssetsSearchCollectionSelectionDelegate? = nil,
        groupsLayoutDelegate: AssetsSearchCollectionViewLayoutDelegate? = nil
    ) {
        self.groupsViewModel = groupsViewModel
        self.selectionDelegate = selectionDelegate
        self.groupsLayoutDelegate = groupsLayoutDelegate
    }
}

// MARK: Private

private extension AssetsSearchCollectionViewDelegate {
    func processAssetSelect(
        _ collectionView: UICollectionView,
        at indexPath: IndexPath
    ) {
        guard
            let groupsLayoutDelegate,
            let groupIndex = AssetsSearchFlowLayout.SectionType.assetsGroupIndexFromSection(
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

// MARK: UICollectionViewDelegateFlowLayout

extension AssetsSearchCollectionViewDelegate: UICollectionViewDelegateFlowLayout {
    func collectionView(
        _ collectionView: UICollectionView,
        layout _: UICollectionViewLayout,
        sizeForItemAt indexPath: IndexPath
    ) -> CGSize {
        guard let groupsLayoutDelegate else { return .zero }

        let cellType = AssetsSearchFlowLayout.CellType(indexPath: indexPath)

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
        switch AssetsSearchFlowLayout.SectionType(section: section) {
        case .assetGroup where groupsViewModel.listGroupStyle == .networks:
            CGSize(
                width: collectionView.frame.width,
                height: AssetListMeasurement.assetHeaderHeight
            )
        case .technical, .assetGroup:
            .zero
        }
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)

        let cellType = AssetsSearchFlowLayout.CellType(indexPath: indexPath)

        switch cellType {
        case .emptyState:
            break
        case .asset:
            processAssetSelect(collectionView, at: indexPath)
        }
    }

    func collectionView(
        _: UICollectionView,
        layout _: UICollectionViewLayout,
        minimumLineSpacingForSectionAt _: Int
    ) -> CGFloat {
        .zero
    }

    func collectionView(
        _: UICollectionView,
        layout _: UICollectionViewLayout,
        insetForSectionAt section: Int
    ) -> UIEdgeInsets {
        let sectionType = AssetsSearchFlowLayout.SectionType(section: section)

        return groupsLayoutDelegate?.sectionInsets(
            for: sectionType,
            section: section
        ) ?? .zero
    }
}
