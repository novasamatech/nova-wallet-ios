import Foundation
import UIKit

extension AssetsSearchFlowLayout {
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
}
