import BigInt

protocol StartStakingStateProtocol {
    var minStake: BigUInt? { get }
    var eraDuration: TimeInterval? { get }
    var unstakingTime: TimeInterval? { get }
    var nextEraStartTime: TimeInterval? { get }
    var maxApy: Decimal? { get }
    var rewardsAutoPayoutThresholdAmount: BigUInt? { get }
    var govThresholdAmount: BigUInt? { get }
    var shouldHaveGovInfo: Bool { get }
    var rewardsDestination: DefaultStakingRewardDestination { get }
}
