import Foundation
import BigInt

struct OperationRewardModel {
    let eventId: String
    let amount: BigUInt
    let priceData: PriceData?
    let validator: DisplayAddress?
    let era: Int?
}
