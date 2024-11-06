import UIKit

final class AssetListNetworksFlowLayout: AssetListFlowLayout {
    static let assetGroupDecoration = "assetNetworkGroupDecoration"

    override func assetGroupDecorationIdentifier() -> String {
        AssetListNetworksFlowLayout.assetGroupDecoration
    }

    override func updateItemsBackgroundAttributesIfNeeded() {
        guard
            let collectionView = collectionView,
            collectionView.numberOfSections >= SectionType.allCases.count else {
            return
        }

        let groupsCount = collectionView.numberOfSections - SectionType.assetsStartingSection

        var groupY: CGFloat = 0.0

        let hasSummarySection = collectionView.numberOfItems(inSection: SectionType.summary.index) > 0

        if hasSummarySection {
            groupY = AssetListMeasurement.accountHeight + SectionType.summary.cellSpacing +
                totalBalanceHeight
        }

        groupY += AssetListMeasurement.summaryInsets.top + AssetListMeasurement.summaryInsets.bottom

        groupY += nftsInsets.top + nftsInsets.bottom

        let hasNfts = collectionView.numberOfItems(inSection: SectionType.nfts.index) > 0

        if hasNfts {
            groupY += AssetListMeasurement.nftsHeight
        }

        groupY += promotionInsets.top + promotionInsets.bottom

        let hasPromotion = collectionView.numberOfItems(inSection: SectionType.promotion.index) > 0

        if hasPromotion {
            groupY += promotionHeight
        }

        groupY += AssetListMeasurement.settingsInsets.top + AssetListMeasurement.settingsHeight +
            AssetListMeasurement.settingsInsets.bottom

        let initAttributes = [UICollectionViewLayoutAttributes]()
        let (attributes, _) = (0 ..< groupsCount).reduce((initAttributes, groupY)) { result, groupIndex in
            let attributes = result.0
            let positionY = result.1

            let section = SectionType.assetsStartingSection + groupIndex
            let numberOfItems = collectionView.numberOfItems(inSection: section)

            let contentHeight = AssetListMeasurement.assetHeaderHeight +
                CGFloat(numberOfItems) * AssetListMeasurement.assetHeight
            let decorationHeight = AssetListMeasurement.assetGroupInsets.top + contentHeight +
                AssetListMeasurement.decorationInset

            let itemsDecorationAttributes = UICollectionViewLayoutAttributes(
                forDecorationViewOfKind: Self.assetGroupDecoration,
                with: IndexPath(item: 0, section: section)
            )

            let decorationWidth = max(collectionView.frame.width - 2 * UIConstants.horizontalInset, 0)
            let size = CGSize(width: decorationWidth, height: decorationHeight)

            let origin = CGPoint(x: UIConstants.horizontalInset, y: positionY)

            itemsDecorationAttributes.frame = CGRect(origin: origin, size: size)
            itemsDecorationAttributes.zIndex = -1

            let newPosition = positionY + AssetListMeasurement.assetGroupInsets.top + contentHeight +
                AssetListMeasurement.assetGroupInsets.bottom

            let newAttributes = attributes + [itemsDecorationAttributes]

            return (newAttributes, newPosition)
        }

        itemsDecorationAttributes = attributes.reduce(into: [:]) { $0[$1.indexPath] = $1 }
    }

    override func assetCellHeight(for _: IndexPath) -> CGFloat {
        AssetListMeasurement.assetHeight
    }

    override func assetGroupInset(for _: Int) -> UIEdgeInsets {
        AssetListMeasurement.assetGroupInsets
    }
}
