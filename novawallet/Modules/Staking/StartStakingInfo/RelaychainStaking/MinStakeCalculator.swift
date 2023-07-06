import BigInt

struct MinStakeCalculator {
    var minNominatorBond: BigUInt?
    var bagListSize: UInt32?
    var networkInfo: NetworkStakingInfo?

    func calculate() -> BigUInt? {
        guard let networkInfo = networkInfo,
              let minNominatorBond = minNominatorBond,
              let bagListSize = bagListSize else {
            return nil
        }

        return networkInfo.calculateMinimumStake(
            given: minNominatorBond,
            votersCount: bagListSize
        )
    }
}

struct EraTimeCalculator {
    var activeEraResult: Result<ActiveEraInfo?, Error>?
    var eraCountdownResult: EraCountdown?

    func calculate() -> TimeInterval? {
        guard let activeEraResult = activeEraResult,
              let activeEra = try? activeEraResult.get(),
              let eraCountdownResult = eraCountdownResult else {
            return nil
        }

        return eraCountdownResult.timeIntervalTillStart(targetEra: eraCountdownResult.activeEra + 1)
    }
}

struct StakingTypeCalculator {
    var minStake: BigUInt?
    var assetBalance: AssetBalance?

    func calculate() -> StartStakingType? {
        guard let minStake = minStake,
              let assetBalance = assetBalance else {
            return nil
        }

        if assetBalance.freeInPlank >= minStake {
            return .directStaking(amount: minStake)
        } else {
            return .nominationPool
        }
    }
}
