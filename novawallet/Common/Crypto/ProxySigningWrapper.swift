import Foundation
import SubstrateSdk
import IrohaCrypto
import SoraKeystore

final class ProxySigningWrapper {
    let signingWrapperFactory: SigningWrapperFactoryProtocol
    let settingsManager: SettingsManagerProtocol
    let uiPresenter: TransactionSigningPresenting

    init(
        signingWrapperFactory: SigningWrapperFactoryProtocol,
        settingsManager: SettingsManagerProtocol,
        uiPresenter: TransactionSigningPresenting
    ) {
        self.signingWrapperFactory = signingWrapperFactory
        self.settingsManager = settingsManager
        self.uiPresenter = uiPresenter
    }

    private func sign(_ originalData: Data, proxyMetaAccount: MetaChainAccountResponse) throws -> IRSignatureProtocol {
        let semaphore = DispatchSemaphore(value: 0)

        var signingResult: TransactionSigningResult?

        DispatchQueue.main.async {
            self.uiPresenter.presentProxyFlow(
                for: originalData,
                proxy: proxyMetaAccount
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

    private func sign(
        _ originalData: Data,
        proxy: ExtrinsicSenderResolution.ResolvedProxy
    ) throws -> IRSignatureProtocol {
        if proxy.failures.isEmpty, let proxyMetaAccount = proxy.proxyAccount {
            return try sign(originalData, proxyMetaAccount: proxyMetaAccount)
        } else {
            // TODO: Handle failures
            throw NoKeysSigningWrapperError.watchOnly
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
        case .evmTransaction:
            throw NoKeysSigningWrapperError.watchOnly
        case .rawBytes:
            // TODO: No raw bytes support error
            throw NoKeysSigningWrapperError.watchOnly
        }
    }
}
