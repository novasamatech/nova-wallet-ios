import Foundation

enum MainTabBarIndex {
    static let wallet = 0
    static let dapps = 1
    static let swaps = 2
    static let staking = 3
    static let more = 4
}

enum MainTabBarMoreItem: CaseIterable {
    case governance
    case settings
}
