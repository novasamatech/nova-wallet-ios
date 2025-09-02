import UIKit

class AssetListFlowLayout: UICollectionViewFlowLayout {
    var animatingTransition: Bool = false

    private var layoutStyle: AssetListGroupsStyle = .tokens

    private var assetSectionsState: [String: AssetListTokenSectionState] = [:]
    private var sectionsExpandableState: [Int: Bool] = [:]

    private var totalBalanceHeight: CGFloat = AssetListMeasurement.totalBalanceHeight
    private var totalBalanceInsets: UIEdgeInsets = AssetListMeasurement.summaryInsets

    private var bannersHeight: CGFloat = AssetListMeasurement.bannerHeight
    private var bannersInsets: UIEdgeInsets = .zero
    private var organizerInsets: UIEdgeInsets = .zero

    private let attributesFactory = AssetDecorationAttributesFactory()

    private var itemsDecorationAttributes: [IndexPath: UICollectionViewLayoutAttributes] = [:]

    override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        let layoutAttributesObjects = super.layoutAttributesForElements(
            in: rect
        )?.map { $0.copy() } as? [UICollectionViewLayoutAttributes]

        let visibleAttributes = itemsDecorationAttributes.filter { _, attributes in
            attributes.frame.intersects(rect)
        }

        return (layoutAttributesObjects ?? []) + visibleAttributes.values
    }

    override func layoutAttributesForDecorationView(
        ofKind elementKind: String,
        at indexPath: IndexPath
    ) -> UICollectionViewLayoutAttributes? {
        guard
            elementKind == assetGroupDecorationIdentifier() || elementKind == AssetListFlowLayout.DecorationIdentifiers.organizer,
            let attributes = itemsDecorationAttributes[indexPath]
        else {
            return nil
        }

        return attributes
    }

    override func prepare() {
        super.prepare()

        itemsDecorationAttributes = [:]
        updateItemsBackgroundAttributesIfNeeded()
    }

    // MARK: Animation

    override func initialLayoutAttributesForAppearingItem(
        at itemIndexPath: IndexPath
    ) -> UICollectionViewLayoutAttributes? {
        let attributes = super.initialLayoutAttributesForAppearingItem(at: itemIndexPath)?
            .copy() as? UICollectionViewLayoutAttributes

        attributes?.alpha = 0.0

        if itemIndexPath.row != 0, !animatingTransition {
            attributes?.transform = getTransformForAnimation()
        }

        return attributes
    }

    override func finalLayoutAttributesForDisappearingItem(
        at itemIndexPath: IndexPath
    ) -> UICollectionViewLayoutAttributes? {
        let attributes = super.finalLayoutAttributesForDisappearingItem(at: itemIndexPath)?
            .copy() as? UICollectionViewLayoutAttributes

        if itemIndexPath.row != 0, !animatingTransition {
            attributes?.transform = getTransformForAnimation()
        }

        return attributes
    }

    override func initialLayoutAttributesForAppearingDecorationElement(
        ofKind elementKind: String,
        at decorationIndexPath: IndexPath
    ) -> UICollectionViewLayoutAttributes? {
        let attributes = super.initialLayoutAttributesForAppearingDecorationElement(
            ofKind: elementKind,
            at: decorationIndexPath
        )?.copy() as? UICollectionViewLayoutAttributes

        return attributes
    }

    override func finalLayoutAttributesForDisappearingDecorationElement(
        ofKind elementKind: String,
        at decorationIndexPath: IndexPath
    ) -> UICollectionViewLayoutAttributes? {
        let attributes = super.finalLayoutAttributesForDisappearingDecorationElement(
            ofKind: elementKind,
            at: decorationIndexPath
        )?.copy() as? UICollectionViewLayoutAttributes

        return attributes
    }

    override func initialLayoutAttributesForAppearingSupplementaryElement(
        ofKind elementKind: String,
        at elementIndexPath: IndexPath
    ) -> UICollectionViewLayoutAttributes? {
        let attributes = super.initialLayoutAttributesForAppearingSupplementaryElement(
            ofKind: elementKind,
            at: elementIndexPath
        )?.copy() as? UICollectionViewLayoutAttributes

        attributes?.alpha = 0.0

        return attributes
    }

    override func finalLayoutAttributesForDisappearingSupplementaryElement(
        ofKind elementKind: String,
        at elementIndexPath: IndexPath
    ) -> UICollectionViewLayoutAttributes? {
        let attributes = super.finalLayoutAttributesForDisappearingSupplementaryElement(
            ofKind: elementKind,
            at: elementIndexPath
        )?.copy() as? UICollectionViewLayoutAttributes

        attributes?.alpha = 0.0

        return attributes
    }
}

// MARK: Private

private extension AssetListFlowLayout {
    func updateItemsBackgroundAttributesIfNeeded() {
        guard let collectionView else { return }

        let initialY = calculateInitialY(for: collectionView)

        let attributes = attributesFactory.createItemsBackgroundAttributes(
            for: layoutStyle,
            collectionView,
            using: sectionsExpandableState,
            assetsStartingSection: SectionType.assetsStartingSection,
            from: initialY
        )

        itemsDecorationAttributes = attributes.reduce(into: [:]) { $0[$1.indexPath] = $1 }
    }

    func calculateInitialY(for collectionView: UICollectionView) -> CGFloat {
        var initialY: CGFloat = 0.0

        let hasSummarySection = collectionView.numberOfItems(inSection: SectionType.summary.index) > 0

        if hasSummarySection {
            initialY = AssetListMeasurement.accountHeight + SectionType.summary.cellSpacing +
                totalBalanceHeight
        }

        initialY += totalBalanceInsets.top + totalBalanceInsets.bottom

        initialY += organizerInsets.top + organizerInsets.bottom

        let numberOfOrganizerItems = collectionView.numberOfItems(inSection: SectionType.organizer.index)

        initialY += CGFloat(numberOfOrganizerItems) * AssetListMeasurement.organizerItemHeight

        initialY += bannersInsets.top + bannersInsets.bottom

        let hasPromotion = collectionView.numberOfItems(inSection: SectionType.banners.index) > 0

        if hasPromotion {
            initialY += bannersHeight
        }

        initialY += AssetListMeasurement.settingsInsets.top
            + AssetListMeasurement.settingsHeight
            + AssetListMeasurement.settingsInsets.bottom

        return initialY
    }

    func getTransformForAnimation() -> CGAffineTransform {
        let scale: CGFloat = 0.65
        return CGAffineTransform(
            scaleX: scale,
            y: scale
        )
    }

    func assetGroupDecorationIdentifier() -> String {
        switch layoutStyle {
        case .networks:
            DecorationIdentifiers.networkGroup
        case .tokens:
            DecorationIdentifiers.tokenGroup
        }
    }

    func assetGroupInset(for section: Int) -> UIEdgeInsets {
        guard let collectionView else { return .zero }

        switch layoutStyle {
        case .networks:
            return AssetListMeasurement.assetGroupInsets
        case .tokens:
            let expanded = collectionView.numberOfItems(inSection: section) > 1
            let expandable = sectionsExpandableState[section] ?? false

            let expandableOffset: CGFloat = expandable && !expanded
                ? AssetListMeasurement.underneathViewHeight
                : 0

            return UIEdgeInsets(
                top: AssetListMeasurement.decorationContentInset,
                left: 0,
                bottom: 8 + AssetListMeasurement.decorationContentInset + expandableOffset,
                right: 0
            )
        }
    }

    func assetCellHeight(for _: IndexPath) -> CGFloat {
        AssetListMeasurement.assetHeight
    }
}

// MARK: Interface

extension AssetListFlowLayout {
    func changeGroupLayoutStyle(to style: AssetListGroupsStyle) {
        layoutStyle = style

        itemsDecorationAttributes = [:]
        updateItemsBackgroundAttributesIfNeeded()
    }

    func updateTotalBalanceHeight(_ height: CGFloat) {
        var newInsets = AssetListMeasurement.summaryInsets

        if organizerInsets == .zero {
            newInsets.bottom = AssetListMeasurement.organizerInsets.bottom
        }

        guard height != totalBalanceHeight || totalBalanceInsets != newInsets else {
            return
        }

        totalBalanceHeight = height
        totalBalanceInsets = newInsets
        invalidateLayout()
    }

    func activatePromotionWithHeight(_ height: CGFloat) {
        let newInsets = AssetListMeasurement.promotionInsets

        guard height != bannersHeight || bannersInsets != newInsets else {
            return
        }

        bannersHeight = height
        bannersInsets = newInsets
        invalidateLayout()
    }

    func deactivatePromotion() {
        let newInsets = UIEdgeInsets.zero

        guard bannersInsets != newInsets else {
            return
        }

        bannersHeight = .zero
        bannersInsets = newInsets
    }

    func setOrganizerActive(_ isActive: Bool) {
        let newInsets = isActive ? AssetListMeasurement.organizerInsets : .zero

        guard organizerInsets != newInsets else {
            return
        }

        organizerInsets = newInsets
        updateTotalBalanceHeight(totalBalanceHeight)
    }

    func cellHeight(
        for type: CellType,
        at indexPath: IndexPath
    ) -> CGFloat {
        switch type {
        case .account:
            AssetListMeasurement.accountHeight
        case .totalBalance:
            totalBalanceHeight
        case .organizerItem:
            AssetListMeasurement.organizerItemHeight
        case .banner:
            bannersHeight
        case .settings:
            AssetListMeasurement.settingsHeight
        case .emptyState:
            AssetListMeasurement.emptyStateCellHeight
        case .asset:
            assetCellHeight(for: indexPath)
        }
    }

    func sectionInsets(
        for type: SectionType,
        section: Int
    ) -> UIEdgeInsets {
        switch type {
        case .summary:
            totalBalanceInsets
        case .organizer:
            organizerInsets
        case .banners:
            bannersInsets
        case .settings:
            AssetListMeasurement.settingsInsets
        case .assetGroup:
            assetGroupInset(for: section)
        }
    }

    func assetSectionIndex(from groupIndex: Int) -> Int {
        SectionType.assetsStartingSection + groupIndex
    }
}

// MARK: Expand/Collapse

extension AssetListFlowLayout {
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

        let expanded = if expandable {
            assetSectionsState[symbol]?.expanded ?? false
        } else {
            false
        }

        assetSectionsState.changeState(with: symbol) {
            $0.byChanging(
                expandable: expandable,
                expanded: expanded
            )
        }
    }
}
