import UIKit

final class WalletListFlowLayout: UICollectionViewFlowLayout {
    static let assetGroupDecoration = "assetGroupDecoration"

    enum Constants {
        static let accountHeight: CGFloat = 56.0
        static let totalBalanceHeight: CGFloat = 124.0
        static let settingsHeight: CGFloat = 56.0
        static let assetHeight: CGFloat = 56.0
    }

    enum SectionType: CaseIterable {
        case summary
        case settings
        case assetGroup

        init(section: Int) {
            switch section {
            case 0:
                self = .summary
            case 1:
                self = .settings
            default:
                self = .assetGroup
            }
        }

        static var assetsStartingSection: Int {
            SectionType.allCases - 1
        }

        var rowSpacing: CGFloat {
            switch self {
            case .summary:
                return 8.0
            case .settings, .assetGroup:
                return 0
            }
        }

        var insets: UIEdgeInsets {
            switch self {
            case .summary:
                return UIEdgeInsets(top: 0, left: 0, bottom: 16, right: 0)
            case .settings:
                return .zero
            case .assetGroup:
                return UIEdgeInsets(top: 8.0, left: 0, bottom: 8.0, right: 0)
            }
        }
    }

    enum CellType {
        case account
        case totalBalance
        case settings
        case asset(index: Int)

        init(indexPath: IndexPath) {
            switch indexPath.section {
            case 0:
                self = indexPath.row == 0 ? .account : .totalBalance
            case 1:
                self = .settings
            default:
                self = .asset(index: indexPath.row)
            }
        }
    }

    private var itemsDecorationAttributes: UICollectionViewLayoutAttributes?

    override func prepare() {
        super.prepare()

        itemsDecorationAttributes = nil
        updateItemsBackgroundAttributesIfNeeded()
    }

    private func updateItemsBackgroundAttributesIfNeeded() {
        guard
            let collectionView = collectionView,
            collectionView.numberOfSections >= SectionType.allCases.count else {
            return
        }

        let groupCount = collectionView.numberOfSections - SectionType.assetsStartingSection

        guard numberOfItems > 0 else {
            return
        }

        guard
            let headerLayoutFrame = collectionView.layoutAttributesForItem(
                at: CellType.header.indexPath
            )?.frame,
            headerUsedFrame != headerLayoutFrame
        else {
            return
        }

        headerUsedFrame = headerLayoutFrame

        let preferredHeight = CGFloat(numberOfItems - 1) * DAppItemView.preferredHeight +
            DAppCategoriesView.preferredHeight

        itemsDecorationAttributes = UICollectionViewLayoutAttributes(
            forDecorationViewOfKind: Self.backgroundDecoration,
            with: IndexPath(item: 0, section: CellType.categories.indexPath.section)
        )

        let size = CGSize(
            width: collectionView.frame.width - 2 * UIConstants.horizontalInset,
            height: preferredHeight + Constants.decorationBottomInset
        )

        let origin = CGPoint(x: UIConstants.horizontalInset, y: headerLayoutFrame.maxY)

        itemsDecorationAttributes?.frame = CGRect(origin: origin, size: size)
        itemsDecorationAttributes?.zIndex = -1
    }
}
