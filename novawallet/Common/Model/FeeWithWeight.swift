import Foundation
import BigInt

struct FeeWithWeight {
    let fee: BigUInt
    let weight: BigUInt

    init?(dispatchInfo: RuntimeDispatchInfo) {
        guard let fee = BigUInt(dispatchInfo.fee) else {
            return nil
        }

        self.fee = fee
        weight = BigUInt(dispatchInfo.weight)
    }

    init(fee: BigUInt, weight: BigUInt) {
        self.fee = fee
        self.weight = weight
    }
}
