import BigInt

struct MinStakeCalculator {
    var minNominatorBondResult: Result<BigUInt?, Error>?
    var bagListSizeResult: Result<UInt32?, Error>?
    var networkInfo: NetworkStakingInfo?

    func calculate() -> BigUInt? {
        guard let networkInfo = networkInfo,
              let minNominatorBondResult = minNominatorBondResult,
              let bagListSizeResult = bagListSizeResult else {
            return nil
        }
        guard let minNominatorBond = try? minNominatorBondResult.get(),
              let bagListSize = try? bagListSizeResult.get() else {
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
