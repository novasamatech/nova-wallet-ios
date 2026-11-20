import Foundation
import SubstrateSdk

struct DAppOperationRequest {
    let transportName: String
    let identifier: String
    let wallet: MetaAccountModel
    let accountId: AccountId
    let dApp: String
    let dAppIcon: URL?
    let operationData: JSON
}

struct DAppOperationResponse {
    let signature: Data?
    let modifiedTransaction: Data?

    // Set only for DAppSigningType.createTransaction: the complete signed extrinsic or the failure for the dApp
    let createTransactionResult: Result<Data, DAppCreateTransactionError>?

    init(signature: Data?, modifiedTransaction: Data?) {
        self.signature = signature
        self.modifiedTransaction = modifiedTransaction
        createTransactionResult = nil
    }

    init(createTransactionResult: Result<Data, DAppCreateTransactionError>) {
        signature = nil
        modifiedTransaction = nil
        self.createTransactionResult = createTransactionResult
    }
}
