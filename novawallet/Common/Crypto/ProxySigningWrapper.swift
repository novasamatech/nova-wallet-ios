import Foundation
import SubstrateSdk
import IrohaCrypto

final class ProxySigningWrapper {
    let signingWrapperFactory: SigningWrapperFactoryProtocol

    init(signingWrapperFactory: SigningWrapperFactoryProtocol) {
        self.signingWrapperFactory = signingWrapperFactory
    }

    private func sign(
        _ originalData: Data,
        proxy: ExtrinsicSenderResolution.ResolvedProxy
    ) throws -> IRSignatureProtocol {
        if proxy.failures.isEmpty, let proxyMetaAccount = proxy.proxyAccount {
            let proxyAccount = proxyMetaAccount.chainAccount

            return try signingWrapperFactory
                .createSigningWrapper(for: proxyMetaAccount.metaId, accountResponse: proxyAccount)
                .sign(
                    originalData,
                    context: .substrateExtrinsic(.init(senderResolution: .current(proxyAccount)))
                )
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
