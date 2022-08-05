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

    init(uiPresenter: TransactionSigningPresenting) {
        self.uiPresenter = uiPresenter
    }
}

extension ParitySignerSigningWrapper: SigningWrapperProtocol {
    func sign(_ originalData: Data) throws -> IRSignatureProtocol {
        let semaphore = DispatchSemaphore(value: 0)

        var signingResult: ParitySignerResult?

        DispatchQueue.main.async {
            self.uiPresenter.presentParitySignerFlow(for: originalData) { result in
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
