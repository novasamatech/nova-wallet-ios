import UIKit

class AssetsSearchTokensFlowLayout: AssetsSearchFlowLayout {
    static let assetGroupDecoration = "assetTokenGroupDecoration"

    private var assetSectionsState: [String: AssetListTokenSectionState] = [:]
    private var sectionsExpandableState: [Int: Bool] = [:]

    func expandAssetGroup(for symbol: String) {
        assetSectionsState.changeState(with: symbol) { $0.byChanging(expanded: true) }
    }

    func collapseAssetGroup(for symbol: String) {
        assetSectionsState.changeState(with: symbol) { $0.byChanging(expanded: false) }
    }

    func state(for symbol: String) -> AssetListTokenSectionState? {
        assetSectionsState[symbol]
    }

    func expanded(for symbol: String) -> Bool {
        assetSectionsState[symbol]?.expanded ?? false
    }

    func changeSection(
        byChanging index: Int,
        for symbol: String
    ) {
        assetSectionsState.changeState(with: symbol) { $0.byChanging(index) }
    }

    func setExpandableSection(
        for symbol: String,
        _ expandable: Bool
    ) {
        guard let sectionIndex = assetSectionsState[symbol]?.index else {
            return
        }

        sectionsExpandableState[sectionIndex] = expandable

        assetSectionsState.changeState(with: symbol) { $0.byChanging(expandable: expandable) }
    }

    override func assetGroupDecorationIdentifier() -> String {
        AssetsSearchTokensFlowLayout.assetGroupDecoration
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
                forDecorationViewOfKind: Self.assetGroupDecoration,
                with: IndexPath(item: 0, section: section)
            )

            itemsDecorationAttributes.isExpanded = expanded

            let decorationWidth = max(collectionView.frame.width - 2 * UIConstants.horizontalInset, 0)
            let size = CGSize(width: decorationWidth, height: decorationHeight)

            let origin = CGPoint(x: UIConstants.horizontalInset, y: positionY)

            itemsDecorationAttributes.frame = CGRect(origin: origin, size: size)
            itemsDecorationAttributes.zIndex = -1

            let newPosition = positionY + decorationHeight + AssetsSearchMeasurement.decorationInset

            let newAttributes = attributes + [itemsDecorationAttributes]

            return (newAttributes, newPosition)
        }

        itemsDecorationAttributes = attributes
    }

    override func assetCellHeight(for _: IndexPath) -> CGFloat {
        let contentHeight = AssetListMeasurement.assetHeight

        return contentHeight
    }

    override func assetGroupInset(for section: Int) -> UIEdgeInsets {
        guard let collectionView else { return .zero }

        let expanded = collectionView.numberOfItems(inSection: section) > 1
        let expandable = sectionsExpandableState[section] ?? false

        let expandableOffset: CGFloat = expandable && !expanded
            ? AssetListMeasurement.underneathViewHeight
            : 0

        var top = AssetListMeasurement.decorationContentInset

        if section == SectionType.assetsStartingSection {
            top += SectionType.technical.insets.top + SectionType.technical.insets.bottom
        }

        return UIEdgeInsets(
            top: top,
            left: 0,
            bottom: 8 + AssetListMeasurement.decorationContentInset + expandableOffset,
            right: 0
        )
    }
}
