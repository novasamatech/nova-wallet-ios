import Foundation
import BigInt
import SubstrateSdk

struct FormattedCall {
    enum Account {
        case local(MetaChainAccountResponse)
        case remote(AccountId)

        var accountId: AccountId {
            switch self {
            case let .local(account):
                return account.chainAccount.accountId
            case let .remote(accountId):
                return accountId
            }
        }
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

        var amount: BigUInt? {
            switch self {
            case let .transfer(transfer):
                transfer.amount
            case .general:
                nil
            }
        }
    }

    let definition: Definition
    let delegatedAccount: Account?
    let decoded: AnyRuntimeCall
}
