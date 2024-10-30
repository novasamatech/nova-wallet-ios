import Foundation
import Operation_iOS

extension SigningWrapperFactoryProtocol {
    func createSigningOperationWrapper(
        dependingOn accountClosure: @escaping () throws -> MetaChainAccountResponse,
        operationQueue: OperationQueue
    ) -> CompoundOperationWrapper<SigningWrapperProtocol> {
        OperationCombiningService.compoundNonOptionalWrapper(
            operationManager: OperationManager(operationQueue: operationQueue)
        ) {
            let account = try accountClosure()

            let signingWrapper = self.createSigningWrapper(
                for: account.metaId,
                accountResponse: account.chainAccount
            )

            return CompoundOperationWrapper.createWithResult(signingWrapper)
        }
    }
}
