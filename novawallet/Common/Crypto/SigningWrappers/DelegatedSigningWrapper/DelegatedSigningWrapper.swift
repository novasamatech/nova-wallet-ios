import Foundation
import SubstrateSdk
import NovaCrypto
import Keystore_iOS

enum DelegatedSigningWrapperError: Error {
    case canceled
    case closed
}

final class DelegatedSigningWrapper {
    let uiPresenter: TransactionSigningPresenting
    let metaId: String

    init(
        metaId: String,
        uiPresenter: TransactionSigningPresenting
    ) {
        self.metaId = metaId
        self.uiPresenter = uiPresenter
    }

    func presentFlow(
        for data: Data,
        delegatedMetaId _: MetaAccountModel.Id,
        resolution: ExtrinsicSenderResolution.ResolvedDelegate,
        substrateContext: ExtrinsicSigningContext.Substrate,
        completion: @escaping TransactionSigningClosure
    ) {
        uiPresenter.presentDelegatedSigningFlow(
            for: data,
            resolution: resolution,
            substrateContext: substrateContext,
            completion: completion
        )
    }

    func presentNotEnoughPermissionsFlow(
        resolution: ExtrinsicSenderResolution.ResolvedDelegate,
        completion: @escaping TransactionSigningClosure
    ) {
        uiPresenter.presentNotEnoughProxyPermissionsFlow(
            resolution: resolution,
            completion: completion
        )
    }
}

private extension DelegatedSigningWrapper {
    func signWithUiFlow(
        _ closure: @escaping (@escaping TransactionSigningClosure) -> Void
    ) throws -> IRSignatureProtocol {
        let semaphore = DispatchSemaphore(value: 0)

        var signingResult: TransactionSigningResult?

        DispatchQueue.main.async {
            closure { result in
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

    func sign(
        _ originalData: Data,
        delegatedMetaId: MetaAccountModel.Id,
        resolution: ExtrinsicSenderResolution.ResolvedDelegate,
        substrateContext: ExtrinsicSigningContext.Substrate
    ) throws -> IRSignatureProtocol {
        if resolution.canSignWithDelegate {
            try signWithUiFlow { completionClosure in
                self.presentFlow(
                    for: originalData,
                    delegatedMetaId: delegatedMetaId,
                    resolution: resolution,
                    substrateContext: substrateContext,
                    completion: completionClosure
                )
            }
        } else {
            try signWithUiFlow { completionClosure in
                self.presentNotEnoughPermissionsFlow(
                    resolution: resolution,
                    completion: completionClosure
                )
            }
        }
    }

    func sign(
        _ originalData: Data,
        sender: ExtrinsicSenderResolution,
        substrateContext: ExtrinsicSigningContext.Substrate
    ) throws -> IRSignatureProtocol {
        switch sender {
        case let .delegate(resolvedDelegate):
            try sign(
                originalData,
                delegatedMetaId: metaId,
                resolution: resolvedDelegate,
                substrateContext: substrateContext
            )
        case .current:
            throw NoKeysSigningWrapperError.watchOnly
        }
    }
}

extension DelegatedSigningWrapper: SigningWrapperProtocol {
    func sign(_ originalData: Data, context: ExtrinsicSigningContext) throws -> IRSignatureProtocol {
        switch context {
        case let .substrateExtrinsic(substrate):
            return try sign(
                originalData,
                sender: substrate.senderResolution,
                substrateContext: substrate
            )
        case .evmTransaction, .rawBytes:
            throw NoSigningSupportError.notSupported(type: .proxy)
        }
    }
}
