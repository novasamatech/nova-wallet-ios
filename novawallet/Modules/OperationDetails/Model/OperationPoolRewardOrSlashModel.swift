import Foundation
import BigInt

struct OperationPoolRewardOrSlashModel {
    let eventId: String
    let amount: BigUInt
    let priceData: PriceData?
    let pool: NominationPools.SelectedPool?
}

extension OperationPoolRewardOrSlashModel {
    func byReplacingPool(_ newPool: NominationPools.SelectedPool) -> OperationPoolRewardOrSlashModel {
        .init(
            eventId: eventId,
            amount: amount,
            priceData: priceData,
            pool: newPool
        )
    }
}
