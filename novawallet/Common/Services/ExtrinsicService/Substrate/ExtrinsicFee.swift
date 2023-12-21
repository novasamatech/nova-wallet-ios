import Foundation
import BigInt

struct ExtrinsicFeePayer {
    enum Reason {
        case proxy
    }

    let accountId: AccountId
    let availableBalance: BigUInt
    let reason: Reason
}

protocol ExtrinsicFeeProtocol {
    var amount: BigUInt { get }
    var payer: ExtrinsicFeePayer? { get }
    var weight: UInt64 { get }
}

struct ExtrinsicFee: ExtrinsicFeeProtocol {
    let amount: BigUInt
    let payer: ExtrinsicFeePayer?
    let weight: UInt64

    init?(dispatchInfo: RuntimeDispatchInfo, payer: ExtrinsicFeePayer? = nil) {
        guard let amount = BigUInt(dispatchInfo.fee) else {
            return nil
        }

        self.amount = amount
        self.payer = payer
        weight = dispatchInfo.weight
    }

    init(amount: BigUInt, payer: ExtrinsicFeePayer?, weight: UInt64) {
        self.amount = amount
        self.payer = payer
        self.weight = weight
    }
}
