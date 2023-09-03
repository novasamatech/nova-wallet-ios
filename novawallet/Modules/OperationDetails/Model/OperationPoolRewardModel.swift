import Foundation
import BigInt

struct OperationPoolRewardModel {
    let eventId: String
    let amount: BigUInt
    let priceData: PriceData?
    let fee: BigUInt
    let feePriceData: PriceData?
    let pool: NominationPools.SelectedPool
}
