import Foundation

struct EvmTransactionMonitorSubmission {
    let status: TransactionStatus

    var transactionHash: String {
        switch status {
        case let .success(successTransaction):
            successTransaction.transactionHash
        case let .failure(failedTransaction):
            failedTransaction.transactionHash
        }
    }
}

extension EvmTransactionMonitorSubmission {
    enum TransactionStatus {
        struct SuccessTransaction {
            let transactionHash: String
            let blockHash: String
        }

        struct FailedTransaction {
            let transactionHash: String
        }

        case success(SuccessTransaction)
        case failure(FailedTransaction)
    }
}
