import Foundation
import NovaCrypto

enum ParitySignerSigningWrapperError: Error {
    case unsupportedContext
}

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
    let type: ParitySignerType

    init(
        uiPresenter: TransactionSigningPresenting,
        metaId: String,
        chainId: ChainModel.Id,
        type: ParitySignerType
    ) {
        self.uiPresenter = uiPresenter
        self.metaId = metaId
        self.chainId = chainId
        self.type = type
    }

    private func presentSigningFlow(
        _ originalData: Data,
        params: ParitySignerConfirmationParams
    ) throws -> IRSignatureProtocol {
        let semaphore = DispatchSemaphore(value: 0)

        var signingResult: TransactionSigningResult?

        DispatchQueue.main.async {
            self.uiPresenter.presentParitySignerFlow(
                for: originalData,
                metaId: self.metaId,
                chainId: self.chainId,
                params: params
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

extension ParitySignerSigningWrapper: SigningWrapperProtocol {
    func sign(_ originalData: Data, context: ExtrinsicSigningContext) throws -> IRSignatureProtocol {
        switch context {
        case let .substrateExtrinsic(substrate):
            let transactionMode = ParitySignerSigningMode.Extrinsic(
                extrinsicMemo: substrate.extrinsicMemo,
                codingFactory: substrate.codingFactory
            )

            let params = ParitySignerConfirmationParams(
                type: type,
                mode: .extrinsic(transactionMode)
            )

            return try presentSigningFlow(originalData, params: params)
        case .rawBytes:
            let params = ParitySignerConfirmationParams(
                type: type,
                mode: .rawBytes
            )

            return try presentSigningFlow(originalData, params: params)
        case .evmTransaction:
            throw ParitySignerSigningWrapperError.unsupportedContext
        }
    }
}
