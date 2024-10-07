import UIKit

enum AssetListMeasurement {
    static let accountHeight: CGFloat = 56.0
    static let totalBalanceHeight: CGFloat = 260.0
    static let totalBalanceWithLocksHeight: CGFloat = 260.0
    static let settingsHeight: CGFloat = 56.0
    static let nftsHeight = 56.0
    static let bannerHeight = 102.0
    static let assetHeight: CGFloat = 56.0
    static let assetHeaderHeight: CGFloat = 45.0
    static let emptyStateCellHeight: CGFloat = 230
    static let decorationInset: CGFloat = 8.0
    static let promotionInsets = UIEdgeInsets(top: 0, left: 0, bottom: 12, right: 0)
    static let summaryInsets = UIEdgeInsets(top: 0, left: 0, bottom: 12, right: 0)
    static let nftsInsets = UIEdgeInsets(top: 0, left: 0, bottom: 12, right: 0)
    static let settingsInsets = UIEdgeInsets.zero
    static let assetGroupInsets = UIEdgeInsets(top: 2.0, left: 0, bottom: 16.0, right: 0)
}

final class AssetListFlowLayout: UICollectionViewFlowLayout {
    static let assetGroupDecoration = "assetGroupDecoration"
    private var totalBalanceHeight: CGFloat = AssetListMeasurement.totalBalanceHeight

    private var promotionHeight: CGFloat = AssetListMeasurement.bannerHeight
    private var promotionInsets: UIEdgeInsets = .zero
    private var nftsInsets: UIEdgeInsets = .zero

    enum SectionType: CaseIterable {
        case summary
        case nfts
        case settings
        case promotion
        case assetGroup

        init(section: Int) {
            switch section {
            case 0:
                self = .summary
            case 1:
                self = .nfts
            case 2:
                self = .promotion
            case 3:
                self = .settings
            default:
                self = .assetGroup
            }
        }

        var index: Int {
            switch self {
            case .summary:
                return 0
            case .nfts:
                return 1
            case .promotion:
                return 2
            case .settings:
                return 3
            case .assetGroup:
                return 4
            }
        }

        static var assetsStartingSection: Int {
            SectionType.allCases.count - 1
        }

        static func assetsGroupIndexFromSection(_ section: Int) -> Int? {
            guard section >= assetsStartingSection else {
                return nil
            }

            return section - assetsStartingSection
        }

        var cellSpacing: CGFloat {
            switch self {
            case .summary:
                return 10.0
            case .settings, .assetGroup, .nfts, .promotion:
                return 0
            }
        }
    }

    enum CellType {
        case account
        case totalBalance
        case yourNfts
        case banner
        case settings
        case asset(sectionIndex: Int, itemIndex: Int)
        case emptyState

        init(indexPath: IndexPath) {
            switch indexPath.section {
            case 0:
                self = indexPath.row == 0 ? .account : .totalBalance
            case 1:
                self = .yourNfts
            case 2:
                self = .banner
            case 3:
                self = indexPath.row == 0 ? .settings : .emptyState
            default:
                self = .asset(sectionIndex: indexPath.section, itemIndex: indexPath.row)
            }
        }

        var indexPath: IndexPath {
            switch self {
            case .account:
                return IndexPath(item: 0, section: 0)
            case .totalBalance:
                return IndexPath(item: 1, section: 0)
            case .yourNfts:
                return IndexPath(item: 0, section: 1)
            case .banner:
                return IndexPath(item: 0, section: 2)
            case .settings:
                return IndexPath(item: 0, section: 3)
            case .emptyState:
                return IndexPath(item: 1, section: 3)
            case let .asset(sectionIndex, itemIndex):
                return IndexPath(item: itemIndex, section: sectionIndex)
            }
        }
    }

    private var itemsDecorationAttributes: [UICollectionViewLayoutAttributes] = []

    override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        let layoutAttributesObjects = super.layoutAttributesForElements(
            in: rect
        )?.map { $0.copy() } as? [UICollectionViewLayoutAttributes]

        let visibleAttributes = itemsDecorationAttributes.filter { attributes in
            attributes.frame.intersects(rect)
        }

        return (layoutAttributesObjects ?? []) + visibleAttributes
    }

    override func layoutAttributesForDecorationView(
        ofKind elementKind: String,
        at indexPath: IndexPath
    ) -> UICollectionViewLayoutAttributes? {
        guard
            elementKind == Self.assetGroupDecoration,
            indexPath.section > SectionType.assetsStartingSection else {
            return nil
        }

        let index = indexPath.section - SectionType.assetsStartingSection

        return itemsDecorationAttributes[index]
    }

    override func prepare() {
        super.prepare()

        itemsDecorationAttributes = []
        updateItemsBackgroundAttributesIfNeeded()
    }

    // swiftlint:disable:next function_body_length
    private func updateItemsBackgroundAttributesIfNeeded() {
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

        itemsDecorationAttributes = attributes
    }

    func updateTotalBalanceHeight(_ height: CGFloat) {
        guard height != totalBalanceHeight else {
            return
        }
        totalBalanceHeight = height
        invalidateLayout()
    }

    func activatePromotionWithHeight(_ height: CGFloat) {
        let newInsets = AssetListMeasurement.promotionInsets

        guard height != promotionHeight || promotionInsets != newInsets else {
            return
        }

        promotionHeight = height
        promotionInsets = newInsets
        invalidateLayout()
    }

    func deactivatePromotion() {
        let newInsets = UIEdgeInsets.zero

        guard promotionInsets != newInsets else {
            return
        }

        promotionInsets = newInsets
        invalidateLayout()
    }

    func setNftsActive(_ isActive: Bool) {
        let newInsets = isActive ? AssetListMeasurement.nftsInsets : .zero

        guard nftsInsets != newInsets else {
            return
        }

        nftsInsets = newInsets
        invalidateLayout()
    }

    func cellHeight(for type: CellType) -> CGFloat {
        switch type {
        case .account:
            return AssetListMeasurement.accountHeight
        case .totalBalance:
            return totalBalanceHeight
        case .yourNfts:
            return AssetListMeasurement.nftsHeight
        case .banner:
            return promotionHeight
        case .settings:
            return AssetListMeasurement.settingsHeight
        case .emptyState:
            return AssetListMeasurement.emptyStateCellHeight
        case .asset:
            return AssetListMeasurement.assetHeight
        }
    }

    func sectionInsets(for type: SectionType) -> UIEdgeInsets {
        switch type {
        case .summary:
            return AssetListMeasurement.summaryInsets
        case .nfts:
            return nftsInsets
        case .promotion:
            return promotionInsets
        case .settings:
            return AssetListMeasurement.settingsInsets
        case .assetGroup:
            return AssetListMeasurement.assetGroupInsets
        }
    }
}
