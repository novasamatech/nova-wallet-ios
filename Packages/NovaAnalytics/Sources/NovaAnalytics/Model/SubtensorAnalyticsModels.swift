import Foundation

public struct SubtensorAnalyticsSubject: Equatable {
    public let network: AnalyticsContentValue
    public let target: StakingAnalyticsTarget

    public init(network: AnalyticsContentValue, target: StakingAnalyticsTarget) {
        self.network = network
        self.target = target
    }
}

public struct StakingFailureDetails: Equatable {
    public let reason: TransactionFailureReason
    public let stage: StakingFailureStage
    public let retryable: Bool

    public init(reason: TransactionFailureReason, stage: StakingFailureStage, retryable: Bool) {
        self.reason = reason
        self.stage = stage
        self.retryable = retryable
    }
}

public struct UnstakeAnalyticsShape: Equatable {
    public let mode: UnstakeMode
    public let hotkeys: CountBucket
    public let hasLocked: Bool
    public let slippage: SlippageBucket?

    public init(mode: UnstakeMode, hotkeys: CountBucket, hasLocked: Bool, slippage: SlippageBucket?) {
        self.mode = mode
        self.hotkeys = hotkeys
        self.hasLocked = hasLocked
        self.slippage = slippage
    }
}

public enum SubnetListInteraction: Equatable {
    case search
    case sort(SubnetSortKey)
    case filterThinPools(Bool)
    case favoriteAdded
    case favoriteRemoved

    var action: SubnetListAction {
        switch self {
        case .search: .search
        case .sort: .sort
        case .filterThinPools: .filterThinPools
        case .favoriteAdded: .favoriteAdded
        case .favoriteRemoved: .favoriteRemoved
        }
    }

    var value: AnalyticsPropertyConvertible? {
        switch self {
        case let .sort(key): key
        case let .filterThinPools(isOn): isOn
        case .search, .favoriteAdded, .favoriteRemoved: nil
        }
    }
}
