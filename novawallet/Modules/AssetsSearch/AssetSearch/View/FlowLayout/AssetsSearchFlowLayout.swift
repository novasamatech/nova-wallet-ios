import UIKit

enum AssetsSearchMeasurement {
    static let emptyStateCellHeight: CGFloat = 168
    static let emptySearchCellWithActionHeight: CGFloat = 230

    static let assetHeight: CGFloat = 56.0
    static let assetHeaderHeight: CGFloat = 45.0
    static let decorationInset: CGFloat = 8.0
    static let assetGroupInsets = UIEdgeInsets(top: 2.0, left: 0, bottom: 16.0, right: 0)
}

class AssetsSearchFlowLayout: UICollectionViewFlowLayout {
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

    var itemsDecorationAttributes: [UICollectionViewLayoutAttributes] = []

    func updateItemsBackgroundAttributesIfNeeded() {
        fatalError("Must be overriden by subsclass")
    }

    func assetCellHeight(for _: IndexPath) -> CGFloat {
        fatalError("Must be overriden by subsclass")
    }

    func assetGroupDecorationIdentifier() -> String {
        fatalError("Must be overriden by subsclass")
    }

    func assetGroupInset(for _: Int) -> UIEdgeInsets {
        fatalError("Must be overriden by subsclass")
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

        let index = indexPath.section - SectionType.assetsStartingSection

        return itemsDecorationAttributes[index]
    }

    override func prepare() {
        super.prepare()

        itemsDecorationAttributes = []
        updateItemsBackgroundAttributesIfNeeded()
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
            .zero
        }
    }

    func assetSectionIndex(from groupIndex: Int) -> Int {
        SectionType.assetsStartingSection + groupIndex
    }
}
