import BigInt

protocol StartStakingStateProtocol {
    var minStake: BigUInt? { get }
    var eraDuration: TimeInterval? { get }
    var unstakingTime: TimeInterval? { get }
    var nextEraStartTime: TimeInterval? { get }
    var maxApy: Decimal? { get }
    var directStakingMinStake: BigUInt? { get }
}
