import Foundation
import NovaCrypto
import Keystore_iOS
import SubstrateSdk

protocol MultisigTransactionSigningPresenting: AnyObject {
    func presentMultisigFlow(
        for data: Data,
        multisigAccountId: MetaAccountModel.Id,
        resolution: ExtrinsicSenderResolution.ResolvedDelegate,
        substrateContext: ExtrinsicSigningContext.Substrate,
        completion: @escaping TransactionSigningClosure
    )

    func presentNotEnoughMultisigPermissionsFlow(
        for metaId: String,
        resolution: ExtrinsicSenderResolution.ResolvedDelegate,
        completion: @escaping TransactionSigningClosure
    )
}

// Default implementation for TransactionSigningPresenting
extension TransactionSigningPresenting where Self: MultisigTransactionSigningPresenting {
    func presentMultisigFlow(
        for _: Data,
        multisigAccountId _: MetaAccountModel.Id,
        resolution _: ExtrinsicSenderResolution.ResolvedDelegate,
        substrateContext _: ExtrinsicSigningContext.Substrate,
        completion: @escaping TransactionSigningClosure
    ) {
        // This will need to be implemented in the actual presenter
        completion(.failure(CommonError.notImplemented))
    }

    func presentNotEnoughMultisigPermissionsFlow(
        for _: String,
        resolution _: ExtrinsicSenderResolution.ResolvedDelegate,
        completion: @escaping TransactionSigningClosure
    ) {
        // This will need to be implemented in the actual presenter
        completion(.failure(CommonError.notImplemented))
    }
}

// Make TransactionSigningPresenter conform to MultisigTransactionSigningPresenting
extension TransactionSigningPresenter: MultisigTransactionSigningPresenting {}
