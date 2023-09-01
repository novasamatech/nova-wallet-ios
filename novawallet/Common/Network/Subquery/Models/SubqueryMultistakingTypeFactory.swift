import Foundation

enum SubqueryMultistakingTypeFactory {
    static let nominationPoolsKey = "nomination-pool"
    
    static func activeStakersTypeKey(for stakingType: StakingType, allTypes: [StakingType]) -> String {
        switch stakingType {
        case .nominationPools:
            let relaychainStaking = allTypes.first { StakingClass(stakingType: $0) == .relaychain }
            
            return relaychainStaking?.rawValue ?? Self.nominationPoolsKey
        default:
            return stakingType.rawValue
        }
    }
    
    static func rewardsTypeKey(for stakingType: StakingType) -> String {
        switch stakingType {
        case .nominationPools:
            return Self.nominationPoolsKey
        default:
            return stakingType.rawValue
        }
    }
}
