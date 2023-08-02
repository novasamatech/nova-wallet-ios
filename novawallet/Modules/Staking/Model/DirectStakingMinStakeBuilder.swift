import Foundation
import BigInt

final class DirectStakingMinStakeBuilder: ValueResolver<NetworkStakingInfo, UInt32?, BigUInt?, Void, Void, BigUInt> {
    init(resultClosure: @escaping (BigUInt) -> Void) {
        super.init(
            p1Store: .undefined,
            p2Store: .undefined,
            p3Store: .undefined,
            p4Store: .defined(()),
            p5Store: .defined(()),
            resolver: { networkStakingInfo, bagSizeList, minNominatorBond, _, _ in
                networkStakingInfo.calculateMinimumStake(given: minNominatorBond, votersCount: bagSizeList)
            },
            resultClosure: resultClosure
        )
    }
}
