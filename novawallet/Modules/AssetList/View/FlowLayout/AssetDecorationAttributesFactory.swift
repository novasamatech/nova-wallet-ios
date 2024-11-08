import Foundation
import UIKit

class AssetDecorationAttributesFactory {
    func createItemsBackgroundAttributes(
        for style: AssetListGroupsStyle,
        _ collectionView: UICollectionView,
        using sectionsExpandableState: [Int: Bool],
        assetsStartingSection: Int,
        from initialY: CGFloat
    ) -> [UICollectionViewLayoutAttributes] {
        switch style {
        case .tokens:
            createAttributesForTokenGroups(
                for: collectionView,
                using: sectionsExpandableState,
                assetsStartingSection: assetsStartingSection,
                initialY: initialY
            )
        case .networks:
            createAttributesForNetworkGroups(
                for: collectionView,
                assetsStartingSection: assetsStartingSection,
                initialY: initialY
            )
        }
    }
}

private extension AssetDecorationAttributesFactory {
    func createAttributesForTokenGroups(
        for collectionView: UICollectionView,
        using sectionsExpandableState: [Int: Bool],
        assetsStartingSection: Int,
        initialY: CGFloat
    ) -> [UICollectionViewLayoutAttributes] {
        let groupsCount = collectionView.numberOfSections - assetsStartingSection

        let initAttributes = [UICollectionViewLayoutAttributes]()
        let (attributes, _) = (0 ..< groupsCount).reduce((initAttributes, initialY)) { result, groupIndex in
            let attributes = result.0
            let positionY = result.1

            let section = assetsStartingSection + groupIndex
            let numberOfItems = collectionView.numberOfItems(inSection: section)

            let expanded = numberOfItems > 1
            let expandable = sectionsExpandableState[section] ?? false

            let mainAssetHeight = AssetListMeasurement.assetHeight + AssetListMeasurement.decorationContentInset * 2

            let contentHeight = expanded
                ? mainAssetHeight + (AssetListMeasurement.assetHeight * CGFloat(numberOfItems - 1))
                : mainAssetHeight

            let underneathViewHeight = expandable && !expanded
                ? AssetListMeasurement.underneathViewHeight
                : 0

            let decorationHeight = contentHeight + underneathViewHeight

            let itemsDecorationAttributes = AssetListCustomLayoutAttributes(
                forDecorationViewOfKind: AssetListFlowLayout.DecorationIdentifiers.tokenGroup,
                with: IndexPath(item: 0, section: section)
            )

            itemsDecorationAttributes.isExpanded = expanded

            let decorationWidth = max(collectionView.frame.width - 2 * UIConstants.horizontalInset, 0)
            let size = CGSize(width: decorationWidth, height: decorationHeight)

            let origin = CGPoint(x: UIConstants.horizontalInset, y: positionY)

            itemsDecorationAttributes.frame = CGRect(origin: origin, size: size)
            itemsDecorationAttributes.zIndex = -1

            let newPosition = positionY + decorationHeight + AssetListMeasurement.decorationInset

            let newAttributes = attributes + [itemsDecorationAttributes]

            return (newAttributes, newPosition)
        }

        return attributes
    }

    func createAttributesForNetworkGroups(
        for collectionView: UICollectionView,
        assetsStartingSection: Int,
        initialY: CGFloat
    ) -> [UICollectionViewLayoutAttributes] {
        let groupsCount = collectionView.numberOfSections - assetsStartingSection

        let initAttributes = [UICollectionViewLayoutAttributes]()
        let (attributes, _) = (0 ..< groupsCount).reduce((initAttributes, initialY)) { result, groupIndex in
            let attributes = result.0
            let positionY = result.1

            let section = assetsStartingSection + groupIndex
            let numberOfItems = collectionView.numberOfItems(inSection: section)

            let contentHeight = AssetListMeasurement.assetHeaderHeight +
                CGFloat(numberOfItems) * AssetListMeasurement.assetHeight
            let decorationHeight = AssetListMeasurement.assetGroupInsets.top + contentHeight +
                AssetListMeasurement.decorationInset

            let itemsDecorationAttributes = UICollectionViewLayoutAttributes(
                forDecorationViewOfKind: AssetListFlowLayout.DecorationIdentifiers.networkGroup,
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

        return attributes
    }
}
