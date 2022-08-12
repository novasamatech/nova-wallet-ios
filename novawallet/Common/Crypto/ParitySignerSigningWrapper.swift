import Foundation
import IrohaCrypto

/**
 *  Implementation of the signing for Parity Signer makes
 *  an assumption that signing is called in one of the background threads.
 *  And one can suspend it (thus blocking the whole operation sending flow) and
 *  launch signing ui in main thread. The callback with
 *  the result should unblock signing thread to continue sending operation.
 */
final class ParitySignerSigningWrapper {
    let uiPresenter: TransactionSigningPresenting
    let metaId: String
    let chainId: ChainModel.Id

    init(
        uiPresenter: TransactionSigningPresenting,
        metaId: String,
        chainId: ChainModel.Id
    ) {
        self.uiPresenter = uiPresenter
        self.metaId = metaId
        self.chainId = chainId
    }
}

extension ParitySignerSigningWrapper: SigningWrapperProtocol {
    func sign(_ originalData: Data) throws -> IRSignatureProtocol {
        let semaphore = DispatchSemaphore(value: 0)

        var signingResult: TransactionSigningResult?

        DispatchQueue.main.async {
            self.uiPresenter.presentParitySignerFlow(
                for: originalData,
                metaId: self.metaId,
                chainId: self.chainId
            ) { result in
                signingResult = result

                semaphore.signal()
            }
        }

        // block tx sending flow until we get signing result from ui
        semaphore.wait()

        switch signingResult {
        case let .success(signature):
            return signature
        case let .failure(error):
            throw error
        case .none:
            throw CommonError.undefined
        }
    }
}
