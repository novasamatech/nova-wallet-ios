import BigInt

struct DirectStakingInfo {
    var minNominatorBond: BigUInt?
    var maxNominatorsCount: UInt32?
    var counterForNominators: UInt32?
    var bagListSize: UInt32?
    var networkInfo: NetworkStakingInfo?
    var calculator: RewardCalculatorEngineProtocol?
}

enum SelectedStakingType {
    case direct(DirectStakingInfo?)

    var apy: Decimal? {
        switch self {
        case let .direct(directStakingInfo):
            return directStakingInfo?.calculator?.calculateMaxEarnings(
                amount: 1,
                isCompound: true,
                period: .year
            )
        }
    }
}
