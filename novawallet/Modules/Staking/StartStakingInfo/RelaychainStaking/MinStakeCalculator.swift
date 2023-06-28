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
