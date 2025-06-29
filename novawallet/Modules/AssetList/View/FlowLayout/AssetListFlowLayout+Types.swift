import Foundation

// MARK: Types

extension AssetListFlowLayout {
    enum SectionType: CaseIterable {
        case summary
        case organizer
        case banners
        case settings
        case assetGroup

        init(section: Int) {
            switch section {
            case 0:
                self = .summary
            case 1:
                self = .organizer
            case 2:
                self = .banners
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
            case .organizer:
                return 1
            case .banners:
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
            case .settings, .assetGroup, .organizer, .banners:
                return 0
            }
        }
    }

    enum CellType {
        case account
        case totalBalance
        case organizerItem(itemIndex: Int)
        case banner
        case settings
        case asset(sectionIndex: Int, itemIndex: Int)
        case emptyState

        init(indexPath: IndexPath) {
            switch indexPath.section {
            case 0:
                self = indexPath.row == 0 ? .account : .totalBalance
            case 1:
                self = .organizerItem(itemIndex: indexPath.row)
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
            case let .organizerItem(itemIndex):
                return IndexPath(item: itemIndex, section: 1)
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

    enum DecorationIdentifiers {
        static let tokenGroup: String = "assetTokenGroupDecoration"
        static let networkGroup: String = "assetNetworkGroupDecoration"
        static let organizer: String = "assetOrganizerDecoration"
    }
}
