import Foundation
import CommonWallet
import IrohaCrypto
import BigInt
import SubstrateSdk

extension TransactionHistoryItem.Status {
    var walletValue: AssetTransactionStatus {
        switch self {
        case .success:
            return .commited
        case .failed:
            return .rejected
        case .pending:
            return .pending
        }
    }
}
