import Foundation
import BigInt

struct OperationSlashModel {
    let eventId: String
    let amount: BigUInt
    let priceData: PriceData?
    let validator: DisplayAddress?
    let era: Int?
}
