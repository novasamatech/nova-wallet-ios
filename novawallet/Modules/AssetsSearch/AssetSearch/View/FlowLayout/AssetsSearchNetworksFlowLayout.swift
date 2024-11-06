import UIKit

final class AssetsSearchNetworksFlowLayout: AssetsSearchFlowLayout {
    static let assetGroupDecoration = "assetNetworkGroupDecoration"

    override func assetGroupDecorationIdentifier() -> String {
        AssetsSearchNetworksFlowLayout.assetGroupDecoration
    }

    override func updateItemsBackgroundAttributesIfNeeded() {
        guard
            let collectionView = collectionView,
            collectionView.numberOfSections >= SectionType.allCases.count else {
            return
        }

        let groupsCount = collectionView.numberOfSections - SectionType.assetsStartingSection

        var groupY: CGFloat = 0.0

        groupY += SectionType.technical.insets.top + SectionType.technical.insets.bottom

        let hasTechnicals = collectionView.numberOfItems(inSection: SectionType.technical.index) > 0

        if hasTechnicals {
            groupY += AssetsSearchMeasurement.emptyStateCellHeight
        }

        let initAttributes = [UICollectionViewLayoutAttributes]()
        let (attributes, _) = (0 ..< groupsCount).reduce((initAttributes, groupY)) { result, groupIndex in
            let attributes = result.0
            let positionY = result.1

            let section = SectionType.assetsStartingSection + groupIndex
            let numberOfItems = collectionView.numberOfItems(inSection: section)

            let contentHeight = AssetsSearchMeasurement.assetHeaderHeight +
                CGFloat(numberOfItems) * AssetsSearchMeasurement.assetHeight
            let decorationHeight = AssetsSearchMeasurement.assetGroupInsets.top + contentHeight +
                AssetsSearchMeasurement.decorationInset

            let itemsDecorationAttributes = UICollectionViewLayoutAttributes(
                forDecorationViewOfKind: Self.assetGroupDecoration,
                with: IndexPath(item: 0, section: section)
            )

            let decorationWidth = max(collectionView.frame.width - 2 * UIConstants.horizontalInset, 0)
            let size = CGSize(width: decorationWidth, height: decorationHeight)

            let origin = CGPoint(x: UIConstants.horizontalInset, y: positionY)

            itemsDecorationAttributes.frame = CGRect(origin: origin, size: size)
            itemsDecorationAttributes.zIndex = -1

            let newPosition = positionY + AssetsSearchMeasurement.assetGroupInsets.top + contentHeight +
                AssetsSearchMeasurement.assetGroupInsets.bottom

            let newAttributes = attributes + [itemsDecorationAttributes]

            return (newAttributes, newPosition)
        }

        itemsDecorationAttributes = attributes
    }

    override func assetCellHeight(for _: IndexPath) -> CGFloat {
        AssetsSearchMeasurement.assetHeight
    }

    override func assetGroupInset(for _: Int) -> UIEdgeInsets {
        AssetsSearchMeasurement.assetGroupInsets
    }
}
