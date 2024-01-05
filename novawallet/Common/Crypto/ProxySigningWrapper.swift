import Foundation
import SubstrateSdk
import IrohaCrypto
import SoraKeystore

enum ProxySigningWrapperError: Error {
    case canceled
    case closed
}

final class ProxySigningWrapper {
    let signingWrapperFactory: SigningWrapperFactoryProtocol
    let settingsManager: SettingsManagerProtocol
    let uiPresenter: TransactionSigningPresenting
    let metaId: String

    init(
        metaId: String,
        signingWrapperFactory: SigningWrapperFactoryProtocol,
        settingsManager: SettingsManagerProtocol,
        uiPresenter: TransactionSigningPresenting
    ) {
        self.metaId = metaId
        self.signingWrapperFactory = signingWrapperFactory
        self.settingsManager = settingsManager
        self.uiPresenter = uiPresenter
    }

    private func signWithUiFlow(
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

    private func sign(_ originalData: Data, proxyMetaAccount: MetaChainAccountResponse) throws -> IRSignatureProtocol {
        try signWithUiFlow { completionClosure in
            self.uiPresenter.presentProxyFlow(
                for: originalData,
                proxy: proxyMetaAccount,
                completion: completionClosure
            )
        }
    }

    private func signWithNotEnoughPermissions(
        metaId: String,
        proxy: ExtrinsicSenderResolution.ResolvedProxy
    ) throws -> IRSignatureProtocol {
        try signWithUiFlow { completionClosure in
            self.uiPresenter.presentNotEnoughProxyPermissionsFlow(
                for: metaId,
                resolution: proxy,
                completion: completionClosure
            )
        }
    }

    private func sign(
        _ originalData: Data,
        proxy: ExtrinsicSenderResolution.ResolvedProxy
    ) throws -> IRSignatureProtocol {
        if proxy.failures.isEmpty, let proxyMetaAccount = proxy.proxyAccount {
            return try sign(originalData, proxyMetaAccount: proxyMetaAccount)
        } else {
            return try signWithNotEnoughPermissions(metaId: metaId, proxy: proxy)
        }
    }

    private func sign(_ originalData: Data, sender: ExtrinsicSenderResolution) throws -> IRSignatureProtocol {
        switch sender {
        case let .proxy(resolvedProxy):
            return try sign(originalData, proxy: resolvedProxy)
        case .current:
            throw NoKeysSigningWrapperError.watchOnly
        }
    }
}

extension ProxySigningWrapper: SigningWrapperProtocol {
    func sign(_ originalData: Data, context: ExtrinsicSigningContext) throws -> IRSignatureProtocol {
        switch context {
        case let .substrateExtrinsic(substrate):
            return try sign(originalData, sender: substrate.senderResolution)
        case .evmTransaction, .rawBytes:
            throw NoSigningSupportError.notSupported(type: .proxy)
        }
    }
}
