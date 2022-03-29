import UIKit

final class WalletListFlowLayout: UICollectionViewFlowLayout {
    static let assetGroupDecoration = "assetGroupDecoration"

    enum Constants {
        static let accountHeight: CGFloat = 56.0
        static let totalBalanceHeight: CGFloat = 96.0
        static let settingsHeight: CGFloat = 56.0
        static let nftsHeight = 56.0
        static let assetHeight: CGFloat = 56.0
        static let assetHeaderHeight: CGFloat = 40.0
        static let emptyStateCellHeight: CGFloat = 198
        static let decorationInset: CGFloat = 8.0
    }

    enum SectionType: CaseIterable {
        case summary
        case nfts
        case settings
        case assetGroup

        init(section: Int) {
            switch section {
            case 0:
                self = .summary
            case 1:
                self = .nfts
            case 2:
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
            case .settings:
                return 2
            case .assetGroup:
                return 3
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
            case .settings, .assetGroup, .nfts:
                return 0
            }
        }

        var insets: UIEdgeInsets {
            switch self {
            case .summary:
                return UIEdgeInsets(top: 0, left: 0, bottom: 8.0, right: 0)
            case .nfts:
                return UIEdgeInsets(top: 0, left: 0, bottom: 12, right: 0)
            case .settings:
                return .zero
            case .assetGroup:
                return UIEdgeInsets(
                    top: 2.0,
                    left: 0,
                    bottom: 16.0,
                    right: 0
                )
            }
        }
    }

    enum CellType {
        case account
        case totalBalance
        case yourNfts
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
            case .settings:
                return IndexPath(item: 0, section: 2)
            case .emptyState:
                return IndexPath(item: 1, section: 2)
            case let .asset(sectionIndex, itemIndex):
                return IndexPath(item: itemIndex, section: sectionIndex)
            }
        }

        var height: CGFloat {
            switch self {
            case .account:
                return Constants.accountHeight
            case .totalBalance:
                return Constants.totalBalanceHeight
            case .yourNfts:
                return Constants.nftsHeight
            case .settings:
                return Constants.settingsHeight
            case .emptyState:
                return Constants.emptyStateCellHeight
            case .asset:
                return Constants.assetHeight
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

        let hasSummarySection = collectionView.numberOfItems(inSection: SectionType.summary.index) > 0

        if hasSummarySection {
            groupY = Constants.accountHeight + SectionType.summary.cellSpacing + Constants.totalBalanceHeight
        }

        groupY += SectionType.summary.insets.top + SectionType.summary.insets.bottom

        groupY += SectionType.nfts.insets.top + SectionType.nfts.insets.bottom

        let hasNfts = collectionView.numberOfItems(inSection: SectionType.nfts.index) > 0

        if hasNfts {
            groupY += CellType.yourNfts.height
        }

        groupY += SectionType.settings.insets.top + Constants.settingsHeight +
            SectionType.settings.insets.bottom

        let (attributes, _) = (0 ..< groupsCount).reduce(
            ([UICollectionViewLayoutAttributes](), groupY)
        ) { result, groupIndex in
            let attributes = result.0
            let positionY = result.1

            let section = SectionType.assetsStartingSection + groupIndex
            let numberOfItems = collectionView.numberOfItems(inSection: section)

            let contentHeight = Constants.assetHeaderHeight + CGFloat(numberOfItems) * Constants.assetHeight
            let decorationHeight = SectionType.assetGroup.insets.top + contentHeight +
                Constants.decorationInset

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
