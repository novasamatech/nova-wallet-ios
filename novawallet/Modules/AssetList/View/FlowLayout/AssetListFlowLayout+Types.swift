import Foundation
import UIKit

// MARK: Types

extension AssetListFlowLayout {
    enum SectionType {
        case summary
        case organizer
        case banners
        case settings
        case assetGroup
        case tokensReveal

        init(section: Int, in collectionView: UICollectionView) {
            switch section {
            case 0:
                self = .summary
            case 1:
                self = .organizer
            case 2:
                self = .banners
            case 3:
                self = .settings
            case collectionView.numberOfSections - 1:
                self = .tokensReveal
            default:
                self = .assetGroup
            }
        }

        var index: Int {
            switch self {
            case .summary:
                return 0
            case .organizer:
                return 1
            case .banners:
                return 2
            case .settings:
                return 3
            case .assetGroup, .tokensReveal:
                return 4
            }
        }

        static var assetsStartingSection: Int {
            SectionType.assetGroup.index
        }

        static var trailingSectionsCount: Int {
            1
        }

        static func assetsGroupIndexFromSection(
            _ section: Int,
            in collectionView: UICollectionView
        ) -> Int? {
            guard
                section >= assetsStartingSection,
                section < collectionView.numberOfSections - 1
            else {
                return nil
            }

            return section - assetsStartingSection
        }

        var cellSpacing: CGFloat {
            switch self {
            case .summary:
                return 10.0
            case .settings, .assetGroup, .organizer, .banners, .tokensReveal:
                return 0
            }
        }
    }

    enum CellType {
        case account
        case alert
        case totalBalance
        case organizerItem(itemIndex: Int)
        case banner
        case settings
        case asset(sectionIndex: Int, itemIndex: Int)
        case emptyState
        case revealRow(sectionIndex: Int)

        init(indexPath: IndexPath, in collectionView: UICollectionView) {
            switch indexPath.section {
            case 0 where indexPath.row == 0:
                self = .account
            case 0 where indexPath.row == 1 && collectionView.numberOfItems(inSection: 0) > 2:
                self = .alert
            case 0:
                self = .totalBalance
            case 1:
                self = .organizerItem(itemIndex: indexPath.row)
            case 2:
                self = .banner
            case 3:
                self = indexPath.row == 0 ? .settings : .emptyState
            case collectionView.numberOfSections - 1:
                self = .revealRow(sectionIndex: indexPath.section)
            default:
                self = .asset(sectionIndex: indexPath.section, itemIndex: indexPath.row)
            }
        }

        var indexPath: IndexPath {
            switch self {
            case .account: IndexPath(item: 0, section: 0)
            case .alert: IndexPath(item: 1, section: 0)
            case .totalBalance: IndexPath(item: 2, section: 0)
            case let .organizerItem(itemIndex): IndexPath(item: itemIndex, section: 1)
            case .banner: IndexPath(item: 0, section: 2)
            case .settings: IndexPath(item: 0, section: 3)
            case .emptyState: IndexPath(item: 1, section: 3)
            case let .asset(sectionIndex, itemIndex): IndexPath(item: itemIndex, section: sectionIndex)
            case let .revealRow(sectionIndex): IndexPath(item: 0, section: sectionIndex)
            }
        }
    }

    enum DecorationIdentifiers {
        static let tokenGroup: String = "assetTokenGroupDecoration"
        static let networkGroup: String = "assetNetworkGroupDecoration"
        static let organizer: String = "assetOrganizerDecoration"
    }
}
