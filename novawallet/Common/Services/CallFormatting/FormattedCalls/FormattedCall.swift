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
        let asset: ChainAsset
    }

    struct Batch {
        enum BatchType {
            case batch
            case batchAll
            case forceBatch

            var path: CallCodingPath {
                switch self {
                case .batch:
                    UtilityPallet.batchPath
                case .batchAll:
                    UtilityPallet.batchAllPath
                case .forceBatch:
                    UtilityPallet.forceBatchPath
                }
            }
            
            var callDescription: LocalizableResource {
                path.callName, 
            }
            
            var fullModuleCallDescription: String {
                
            }
        }
        let type: UtilityPallet.BatchType
    }

    struct General {
        let callPath: CallCodingPath
    }

    enum Definition {
        case transfer(Transfer)
        case batch(Batch)
        case general(General)

        var amount: BigUInt? {
            switch self {
            case let .transfer(transfer):
                transfer.amount
            case .general, .batch:
                nil
            }
        }

        var amountAsset: ChainAsset? {
            switch self {
            case let .transfer(transfer):
                transfer.asset
            case .general, .batch:
                nil
            }
        }
    }

    let definition: Definition
    let delegatedAccount: Account?
    let decoded: AnyRuntimeCall
}
