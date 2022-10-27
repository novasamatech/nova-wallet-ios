import Foundation
import BigInt
import SubstrateSdk

struct ReferendumActionLocal {
    struct AmountSpendDetails {
        let amount: BigUInt
        let beneficiary: MultiAddress
    }

    let amountSpendDetails: AmountSpendDetails?
    let call: RuntimeCall<JSON>?
}
