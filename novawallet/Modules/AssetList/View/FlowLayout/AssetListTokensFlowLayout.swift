import UIKit

struct AssetListTokenSectionState {
    let expandable: Bool
    let expanded: Bool
    let index: Int

    func byChanging(
        expandable: Bool? = nil,
        expanded: Bool? = nil,
        _ index: Int? = nil
    ) -> Self {
        .init(
            expandable: expandable ?? self.expandable,
            expanded: expanded ?? self.expanded,
            index: index ?? self.index
        )
    }
}

extension [String: AssetListTokenSectionState] {
    mutating func changeState(
        with key: String,
        closure: (Value) -> Value
    ) {
        if let value = self[key] {
            self[key] = closure(value)
        } else {
            self[key] = closure(
                AssetListTokenSectionState(
                    expandable: false,
                    expanded: false,
                    index: 0
                )
            )
        }
    }
}

enum Measurements {
    static let mainAssetHeight: CGFloat = 56.0
    static let assetHeight: CGFloat = 52.0
    static let underneathViewHeight: CGFloat = 4
    static let decorationContentInset: CGFloat = 4
}

class AssetListTokensFlowLayout: AssetListFlowLayout {
    static let assetGroupDecoration = "assetTokenGroupDecoration"

    private var assetSectionsState: [String: AssetListTokenSectionState] = [:]
    private var sectionsExpandableState: [Int: Bool] = [:]

    func expandAssetSection(for symbol: String) {
        assetSectionsState.changeState(with: symbol) { $0.byChanging(expanded: true) }
    }

    func collapseAssetSection(at symbol: String) {
        assetSectionsState.changeState(with: symbol) { $0.byChanging(expanded: false) }
    }

    func state(for symbol: String) -> AssetListTokenSectionState? {
        assetSectionsState[symbol]
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
        AssetListTokensFlowLayout.assetGroupDecoration
    }

    override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        let layoutAttributesObjects = super.layoutAttributesForElements(
            in: rect
        )?.map { $0.copy() } as? [UICollectionViewLayoutAttributes]

        let visibleAttributes = itemsDecorationAttributes.filter { attributes in
            attributes.frame.intersects(rect)
        }

        return (layoutAttributesObjects ?? []) + visibleAttributes
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

            let expanded = numberOfItems > 1
            let expandable = sectionsExpandableState[section] ?? false

            let mainAssetHeight = Measurements.mainAssetHeight + Measurements.decorationContentInset * 2

            let contentHeight = expanded
                ? mainAssetHeight + (Measurements.mainAssetHeight * CGFloat(numberOfItems - 1))
                : mainAssetHeight

            let underneathViewHeight = expandable && !expanded
                ? Measurements.underneathViewHeight
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

            let newPosition = positionY + decorationHeight + AssetListMeasurement.decorationInset

            let newAttributes = attributes + [itemsDecorationAttributes]

            return (newAttributes, newPosition)
        }

        itemsDecorationAttributes = attributes
    }

    override func assetCellHeight(for _: IndexPath) -> CGFloat {
        let contentHeight = Measurements.mainAssetHeight

        return contentHeight
    }

    override func assetGroupInset(for section: Int) -> UIEdgeInsets {
        guard let collectionView else { return .zero }

        let expanded = collectionView.numberOfItems(inSection: section) > 1
        let expandable = sectionsExpandableState[section] ?? false

        let expandableOffset: CGFloat = expandable && !expanded
            ? Measurements.underneathViewHeight
            : 0

        return UIEdgeInsets(
            top: Measurements.decorationContentInset,
            left: 0,
            bottom: 8 + Measurements.decorationContentInset + expandableOffset,
            right: 0
        )
    }
}

class AssetListCustomLayoutAttributes: UICollectionViewLayoutAttributes {
    var isExpanded: Bool = false

    override func copy(with zone: NSZone? = nil) -> Any {
        let copy = super.copy(with: zone)
        let assetListAttributes = copy as? AssetListCustomLayoutAttributes

        assetListAttributes?.isExpanded = isExpanded

        return assetListAttributes ?? copy
    }

    override func isEqual(_ object: Any?) -> Bool {
        guard let other = object as? AssetListCustomLayoutAttributes else {
            return false
        }
        return other.isExpanded == isExpanded && super.isEqual(object)
    }
}
