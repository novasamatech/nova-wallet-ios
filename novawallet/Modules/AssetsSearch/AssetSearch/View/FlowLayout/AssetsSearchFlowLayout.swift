import UIKit

enum AssetsSearchMeasurement {
    static let emptyStateCellHeight: CGFloat = 168
    static let emptySearchCellWithActionHeight: CGFloat = 230
}

class AssetsSearchFlowLayout: UICollectionViewFlowLayout {
    private var assetSectionsState: [String: AssetListTokenSectionState] = [:]
    private var sectionsExpandableState: [Int: Bool] = [:]

    private var layoutStyle: AssetListGroupsStyle = .tokens

    private var itemsDecorationAttributes: [IndexPath: UICollectionViewLayoutAttributes] = [:]

    private let attributesFactory = AssetDecorationAttributesFactory()

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
            elementKind == assetGroupDecorationIdentifier(),
            indexPath.section > SectionType.assetsStartingSection,
            indexPath.section < itemsDecorationAttributes.count
        else {
            return nil
        }

        return itemsDecorationAttributes[indexPath]
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

        if itemIndexPath.row != 0 {
            attributes?.transform = getTransformForAnimation()
        }

        return attributes
    }

    override func finalLayoutAttributesForDisappearingItem(
        at itemIndexPath: IndexPath
    ) -> UICollectionViewLayoutAttributes? {
        let attributes = super.finalLayoutAttributesForDisappearingItem(at: itemIndexPath)?
            .copy() as? UICollectionViewLayoutAttributes

        if itemIndexPath.row != 0 {
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

// MARK: Interface

extension AssetsSearchFlowLayout {
    func changeGroupLayoutStyle(to style: AssetListGroupsStyle) {
        layoutStyle = style

        itemsDecorationAttributes = [:]
        updateItemsBackgroundAttributesIfNeeded()
    }

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

    func cellHeight(
        for type: CellType,
        at indexPath: IndexPath
    ) -> CGFloat {
        switch type {
        case .emptyState:
            return AssetListMeasurement.emptyStateCellHeight
        case .asset:
            return assetCellHeight(for: indexPath)
        }
    }

    func sectionInsets(
        for type: SectionType,
        section: Int
    ) -> UIEdgeInsets {
        switch type {
        case .assetGroup:
            assetGroupInset(for: section)
        case .technical:
            SectionType.technical.insets
        }
    }

    func assetSectionIndex(from groupIndex: Int) -> Int {
        SectionType.assetsStartingSection + groupIndex
    }
}

// MARK: Private

private extension AssetsSearchFlowLayout {
    func getTransformForAnimation() -> CGAffineTransform {
        let scale: CGFloat = 0.65
        return CGAffineTransform(
            scaleX: scale,
            y: scale
        )
    }

    func updateItemsBackgroundAttributesIfNeeded() {
        guard
            let collectionView,
            collectionView.numberOfSections >= SectionType.allCases.count
        else {
            return
        }

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

        initialY += SectionType.technical.insets.top + SectionType.technical.insets.bottom

        let hasTechnicals = collectionView.numberOfItems(inSection: SectionType.technical.index) > 0

        if hasTechnicals {
            initialY += AssetsSearchMeasurement.emptyStateCellHeight
        }

        return initialY
    }

    func assetCellHeight(for _: IndexPath) -> CGFloat {
        AssetListMeasurement.assetHeight
    }

    func assetGroupDecorationIdentifier() -> String {
        switch layoutStyle {
        case .networks:
            AssetListFlowLayout.DecorationIdentifiers.networkGroup
        case .tokens:
            AssetListFlowLayout.DecorationIdentifiers.tokenGroup
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
}
