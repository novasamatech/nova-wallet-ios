import Foundation
import SubstrateSdk
import IrohaCrypto

final class ProxySigningWrapper {
    let signingWrapperFactory: SigningWrapperFactoryProtocol

    init(signingWrapperFactory: SigningWrapperFactoryProtocol) {
        self.signingWrapperFactory = signingWrapperFactory
    }
}

extension ProxySigningWrapper: SigningWrapperProtocol {
    func sign(_ originalData: Data, context: ExtrinsicSigningContext) throws -> IRSignatureProtocol {
        guard
            case let .substrateExtrinsic(substrate) = context,
            case let .proxy(proxy) = substrate.senderResolution else {
            throw CommonError.dataCorruption
        }

        return try signingWrapperFactory
            .createSigningWrapper(for: proxy.proxyAccount.metaId, accountResponse: proxy.proxyAccount.chainAccount)
            .sign(
                originalData,
                context: .substrateExtrinsic(.init(
                    senderResolution: .current(proxy.proxyAccount.chainAccount),
                    chainFormat: substrate.chainFormat,
                    cryptoType: proxy.proxyAccount.chainAccount.cryptoType
                ))
            )
    }
}
