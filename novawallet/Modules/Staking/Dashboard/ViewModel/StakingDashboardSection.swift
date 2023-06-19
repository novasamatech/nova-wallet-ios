import UIKit

enum StakingDashboardSection: Int, CaseIterable {
    case walletSwitch
    case activeStakings
    case inactiveStakings
    case moreOptions

    var rowHeight: CGFloat {
        switch self {
        case .walletSwitch:
            return 45
        case .activeStakings:
            return 160
        case .inactiveStakings:
            return 64
        case .moreOptions:
            return 52
        }
    }

    var loadingCellsCount: Int {
        switch self {
        case .walletSwitch, .moreOptions:
            return 0
        case .activeStakings:
            return 1
        case .inactiveStakings:
            return 3
        }
    }

    var headerHeight: CGFloat {
        switch self {
        case .activeStakings, .walletSwitch, .moreOptions:
            return 0
        case .inactiveStakings:
            return 32
        }
    }

    var spacing: CGFloat {
        8
    }

    var insets: UIEdgeInsets {
        switch self {
        case .walletSwitch:
            return UIEdgeInsets(top: 0, left: 0, bottom: 16, right: 0)
        case .activeStakings:
            return UIEdgeInsets(top: 0, left: 0, bottom: 24, right: 0)
        case .inactiveStakings:
            return UIEdgeInsets(top: 16, left: 0, bottom: 0, right: 0)
        case .moreOptions:
            return UIEdgeInsets(top: 8, left: 0, bottom: 8, right: 0)
        }
    }
}
