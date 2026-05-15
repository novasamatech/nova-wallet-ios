import Foundation
import BigInt

enum StartStakingFeeIdFactory {
    static func generateFeeId(
        for stakingOption: SelectedStakingOption,
        amount: BigUInt
    ) -> TransactionFeeId {
        switch stakingOption {
        case let .direct(validators):
            return "direct" + "\(validators.targets.count)" + "\(amount)"
        case let .pool(preparedPool):
            return "pool" + "\(preparedPool.selectedPool.poolId)" + "\(amount)"
        }
    }
}
