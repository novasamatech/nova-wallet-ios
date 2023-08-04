import Foundation

protocol NominationPoolsRewardEngineProtocol {
    func calculateMaxReturn(
        poolId: NominationPools.PoolId,
        isCompound: Bool,
        period: CalculationPeriod
    ) throws -> NominationPools.PoolApy

    func calculateMaxReturn(isCompound: Bool, period: CalculationPeriod) throws -> NominationPools.PoolApy
}

enum NominationPoolsRewardEngineError: Error {
    case noPoolFound(NominationPools.PoolId)
}

final class NominationPoolsRewardEngine {
    let innerRewardCalculator: RewardCalculatorEngineProtocol
    let activePools: [NominationPools.PoolId: NominationPools.ActivePool]
    let bondingDetails: [NominationPools.PoolId: NominationPools.BondedPool]

    private var maxPoolId: NominationPools.PoolId?

    init(
        innerRewardCalculator: RewardCalculatorEngineProtocol,
        activePools: [NominationPools.PoolId: NominationPools.ActivePool],
        bondingDetails: [NominationPools.PoolId: NominationPools.BondedPool]
    ) {
        self.innerRewardCalculator = innerRewardCalculator
        self.activePools = activePools
        self.bondingDetails = bondingDetails
    }

    func setup() {
        maxPoolId = activePools.keys.max { poolId1, poolId2 in
            let maxApy1 = (try? calculateMaxReturn(poolId: poolId1, isCompound: false, period: .year))?.maxApy ?? 0
            let maxApy2 = (try? calculateMaxReturn(poolId: poolId2, isCompound: false, period: .year))?.maxApy ?? 0

            return maxApy1 <= maxApy2
        }
    }
}

extension NominationPoolsRewardEngine: NominationPoolsRewardEngineProtocol {
    func calculateMaxReturn(
        poolId: NominationPools.PoolId,
        isCompound: Bool,
        period: CalculationPeriod
    ) throws -> NominationPools.PoolApy {
        guard
            let activePool = activePools[poolId],
            let bondedPool = bondingDetails[poolId] else {
            throw NominationPoolsRewardEngineError.noPoolFound(poolId)
        }

        let optMaxReturn = try activePool.validators
            .map { validator in
                try innerRewardCalculator.calculateValidatorReturn(
                    validatorAccountId: validator,
                    isCompound: isCompound,
                    period: period
                )
            }
            .max()

        guard let maxReturn = optMaxReturn else {
            throw CommonError.dataCorruption
        }

        let commission = bondedPool.commission?.current.flatMap { Decimal.fromSubstratePerbill(value: $0.percent) } ?? 0

        let maxApy = maxReturn * (1 - commission)

        return .init(
            poolId: activePool.poolId,
            bondedAccountId: activePool.bondedAccountId,
            maxApy: maxApy
        )
    }

    func calculateMaxReturn(isCompound: Bool, period: CalculationPeriod) throws -> NominationPools.PoolApy {
        if maxPoolId == nil {
            setup()
        }

        guard let maxPoolId = maxPoolId else {
            throw CommonError.dataCorruption
        }

        return try calculateMaxReturn(poolId: maxPoolId, isCompound: isCompound, period: period)
    }
}
