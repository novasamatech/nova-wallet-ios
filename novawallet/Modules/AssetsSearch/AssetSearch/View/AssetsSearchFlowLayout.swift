import UIKit

enum AssetsSearchMeasurement {
    static let emptyStateCellHeight: CGFloat = 168
}

final class AssetsSearchFlowLayout: UICollectionViewFlowLayout {
    static let assetGroupDecoration = "assetGroupDecoration"

    enum SectionType: CaseIterable {
        case technical
        case assetGroup

        init(section: Int) {
            switch section {
            case 0:
                self = .technical
            default:
                self = .assetGroup
            }
        }

        var index: Int {
            switch self {
            case .technical:
                return 0
            case .assetGroup:
                return 1
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
            case .assetGroup, .technical:
                return 0
            }
        }

        var insets: UIEdgeInsets {
            switch self {
            case .technical:
                return UIEdgeInsets(
                    top: 12.0,
                    left: 0,
                    bottom: 0.0,
                    right: 0
                )
            case .assetGroup:
                return UIEdgeInsets(
                    top: 0.0,
                    left: 0,
                    bottom: 16.0,
                    right: 0
                )
            }
        }
    }

    enum CellType {
        case asset(sectionIndex: Int, itemIndex: Int)
        case emptyState

        init(indexPath: IndexPath) {
            switch indexPath.section {
            case 0:
                self = .emptyState
            default:
                self = .asset(sectionIndex: indexPath.section, itemIndex: indexPath.row)
            }
        }

        var indexPath: IndexPath {
            switch self {
            case .emptyState:
                return IndexPath(item: 0, section: 0)
            case let .asset(sectionIndex, itemIndex):
                return IndexPath(item: itemIndex, section: sectionIndex)
            }
        }

        var height: CGFloat {
            switch self {
            case .emptyState:
                return AssetsSearchMeasurement.emptyStateCellHeight
            case .asset:
                return AssetListMeasurement.assetHeight
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

    private func updateItemsBackgroundAttributesIfNeeded() {
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
            groupY += AssetListMeasurement.emptyStateCellHeight
        }

        let (attributes, _) = (0 ..< groupsCount).reduce(
            ([UICollectionViewLayoutAttributes](), groupY)
        ) { result, groupIndex in
            let attributes = result.0
            let positionY = result.1

            let section = SectionType.assetsStartingSection + groupIndex
            let numberOfItems = collectionView.numberOfItems(inSection: section)

            let contentHeight = AssetListMeasurement.assetHeaderHeight +
                CGFloat(numberOfItems) * AssetListMeasurement.assetHeight
            let decorationHeight = SectionType.assetGroup.insets.top + contentHeight +
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

            let newPosition = positionY + SectionType.assetGroup.insets.top + contentHeight +
                SectionType.assetGroup.insets.bottom

            let newAttributes = attributes + [itemsDecorationAttributes]

            return (newAttributes, newPosition)
        }

        itemsDecorationAttributes = attributes
    }
}
