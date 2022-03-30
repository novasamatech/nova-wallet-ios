import Foundation
import BigInt

struct OperationRewardModel {
    let eventId: String
    let amount: BigUInt
    let validator: DisplayAddress?
    let era: Int?
}
