import Foundation
@testable import novawallet
import Operation_iOS

final class ExtrinsicSenderResolutionFactoryStub {
    let resolver: ExtrinsicSenderResolving

    convenience init(address: String, chain: ChainModel) throws {
        let accountId = try address.toAccountId(using: chain.chainFormat)

        self.init(accountId: accountId, chain: chain)
    }

    init(accountId: AccountId, chain: ChainModel) {
        resolver = ExtrinsicCurrentSenderResolver(
            currentAccount: .init(
                metaId: UUID().uuidString,
                chainId: chain.chainId,
                accountId: accountId,
                publicKey: accountId,
                name: "Stub",
                cryptoType: .sr25519,
                addressPrefix: chain.addressPrefix,
                isEthereumBased: chain.isEthereumBased,
                isChainAccount: true,
                type: .secrets
            )
        )
    }

    init(resolver: ExtrinsicSenderResolving) {
        self.resolver = resolver
    }
}

extension ExtrinsicSenderResolutionFactoryStub: ExtrinsicSenderResolutionFactoryProtocol {
    func createWrapper() -> CompoundOperationWrapper<ExtrinsicSenderResolving> {
        CompoundOperationWrapper.createWithResult(resolver)
    }
}

final class ExtrinsicSenderResolutionFacadeStub: ExtrinsicSenderResolutionFacadeProtocol {
    func createResolutionFactory(
        for chainAccount: ChainAccountResponse,
        chainModel _: ChainModel
    ) -> ExtrinsicSenderResolutionFactoryProtocol {
        ExtrinsicSenderResolutionFactoryStub(
            resolver: ExtrinsicCurrentSenderResolver(
                currentAccount: chainAccount
            )
        )
    }
}
