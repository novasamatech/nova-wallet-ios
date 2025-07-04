import Foundation
import BigInt
import SubstrateSdk

struct FormattedCall {
    enum Account {
        case local(MetaChainAccountResponse)
        case remote(AccountId)
    }

    struct Transfer {
        let amount: BigUInt
        let account: Account
    }

    struct General {
        let callPath: CallCodingPath
    }

    enum Definition {
        case transfer(Transfer)
        case general(General)
    }

    let definition: Definition
    let delegatedAccount: Account?
    let decoded: AnyRuntimeCall
}
