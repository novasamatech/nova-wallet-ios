import Foundation
import BigInt
import SubstrateSdk

struct ReferendumActionLocal {
    struct AmountSpendDetails {
        let amount: BigUInt
        let beneficiaryAccountId: AccountId
    }

    let amountSpendDetails: AmountSpendDetails?
    let call: RuntimeCall<JSON>?
}
