import Foundation

enum CollatorsSortType: Equatable {
    case rewards
    case minStake
    case totalStake
    case ownStake

    static var defaultType: CollatorsSortType { .rewards }
}

extension Array where Element == CollatorSelectionInfo {
    func sortedByType(_ type: CollatorsSortType) -> [CollatorSelectionInfo] {
        switch type {
        case .rewards:
            return sorted { $0.apr > $1.apr }
        case .minStake:
            return sorted { $0.minStake > $1.minStake }
        case .totalStake:
            return sorted { $0.totalStake > $1.totalStake }
        case .ownStake:
            return sorted { $0.ownStake > $1.ownStake }
        }
    }
}
