import Foundation
import UIKit

final class DAppListFlowLayout: UICollectionViewFlowLayout {
    enum CellType {
        case header
        case notLoaded
        case dAppHeader
        case categories
        case dapp(index: Int)

        init?(indexPath: IndexPath) {
            if indexPath.section == 0 {
                switch indexPath.row {
                case 0:
                    self = .header
                case 1:
                    self = .dAppHeader
                case 2:
                    self = .notLoaded
                default:
                    return nil
                }
            } else if indexPath.section == 1 {
                switch indexPath.row {
                case 0:
                    self = .categories
                default:
                    self = .dapp(index: indexPath.row - 1)
                }
            } else {
                return nil
            }
        }

        var indexPath: IndexPath {
            switch self {
            case .header:
                return IndexPath(item: 0, section: 0)
            case .dAppHeader:
                return IndexPath(item: 1, section: 0)
            case .notLoaded:
                return IndexPath(item: 2, section: 0)
            case .categories:
                return IndexPath(item: 0, section: 1)
            case let .dapp(index):
                return IndexPath(item: index + 1, section: 1)
            }
        }
    }

    private enum Constants {
        static let decorationBottomInset: CGFloat = 8.0
    }

    static let backgroundDecoration = "backgroundDecoration"

    private var itemsDecorationAttributes: UICollectionViewLayoutAttributes?
    private var headerUsedFrame: CGRect?

    override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        let layoutAttributesObjects = super.layoutAttributesForElements(
            in: rect
        )?.map { $0.copy() } as? [UICollectionViewLayoutAttributes]
        layoutAttributesObjects?.forEach { layoutAttributes in
            if layoutAttributes.representedElementCategory == .cell {
                if let newFrame = layoutAttributesForItem(at: layoutAttributes.indexPath)?.frame {
                    layoutAttributes.frame = newFrame
                }
            }
        }

        updateItemsBackgroundAttributesIfNeeded()

        if
            let itemsDecorationAttributes = itemsDecorationAttributes,
            itemsDecorationAttributes.frame.intersects(rect),
            let copiedAttributes = itemsDecorationAttributes.copy() as? UICollectionViewLayoutAttributes {
            return (layoutAttributesObjects ?? []) + [copiedAttributes]
        } else {
            return layoutAttributesObjects
        }
    }

    override func layoutAttributesForItem(at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        guard let collectionView = collectionView,
              let layoutAttributes = super.layoutAttributesForItem(
                  at: indexPath
              )?.copy() as? UICollectionViewLayoutAttributes else {
            return nil
        }

        layoutAttributes.frame.origin.x = sectionInset.left
        layoutAttributes.frame.size.width = collectionView.safeAreaLayoutGuide.layoutFrame.width -
            sectionInset.left - sectionInset.right
        return layoutAttributes
    }

    override func layoutAttributesForDecorationView(
        ofKind elementKind: String,
        at _: IndexPath
    ) -> UICollectionViewLayoutAttributes? {
        guard elementKind == Self.backgroundDecoration else {
            return nil
        }

        updateItemsBackgroundAttributesIfNeeded()

        return itemsDecorationAttributes
    }

    override func prepare() {
        super.prepare()

        itemsDecorationAttributes = nil
        headerUsedFrame = nil
    }

    private func updateItemsBackgroundAttributesIfNeeded() {
        let dAppSection = CellType.categories.indexPath.section
        guard let collectionView = collectionView, collectionView.numberOfSections > dAppSection else {
            return
        }

        let numberOfItems = collectionView.numberOfItems(inSection: dAppSection)

        guard numberOfItems > 0 else {
            return
        }

        guard
            let headerLayoutFrame = collectionView.layoutAttributesForItem(
                at: CellType.dAppHeader.indexPath
            )?.frame,
            headerLayoutFrame.origin.y > 0.0,
            headerUsedFrame != headerLayoutFrame
        else {
            return
        }

        headerUsedFrame = headerLayoutFrame

        let preferredHeight = CGFloat(numberOfItems - 1) * DAppItemView.preferredHeight +
            DAppCategoriesView.preferredHeight

        itemsDecorationAttributes = UICollectionViewLayoutAttributes(
            forDecorationViewOfKind: Self.backgroundDecoration,
            with: IndexPath(item: 0, section: dAppSection)
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
