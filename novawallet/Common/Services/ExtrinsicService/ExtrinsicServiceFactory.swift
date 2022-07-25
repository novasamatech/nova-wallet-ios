import RobinHood
import SoraKeystore
import SubstrateSdk

protocol ExtrinsicServiceFactoryProtocol {
    func createService(
        accountId: AccountId,
        chain: ChainModel,
        cryptoType: MultiassetCryptoType
    ) -> ExtrinsicServiceProtocol

    func createOperationFactory(
        accountId: AccountId,
        chain: ChainModel,
        cryptoType: MultiassetCryptoType
    ) -> ExtrinsicOperationFactoryProtocol

    func createSigningWrapper(
        metaId: String,
        account: ChainAccountResponse
    ) -> SigningWrapperProtocol
}

final class ExtrinsicServiceFactory {
    private let runtimeRegistry: RuntimeCodingServiceProtocol
    private let engine: JSONRPCEngine
    private let operationManager: OperationManagerProtocol
    private let signingWrapperFactory: SigningWrapperFactoryProtocol

    init(
        runtimeRegistry: RuntimeCodingServiceProtocol,
        engine: JSONRPCEngine,
        operationManager: OperationManagerProtocol,
        signingWrapperFactory: SigningWrapperFactoryProtocol
    ) {
        self.runtimeRegistry = runtimeRegistry
        self.engine = engine
        self.operationManager = operationManager
        self.signingWrapperFactory = signingWrapperFactory
    }
}

extension ExtrinsicServiceFactory: ExtrinsicServiceFactoryProtocol {
    func createService(
        accountId: AccountId,
        chain: ChainModel,
        cryptoType: MultiassetCryptoType
    ) -> ExtrinsicServiceProtocol {
        ExtrinsicService(
            accountId: accountId,
            chain: chain,
            cryptoType: cryptoType,
            runtimeRegistry: runtimeRegistry,
            engine: engine,
            operationManager: operationManager
        )
    }

    func createOperationFactory(
        accountId: AccountId,
        chain: ChainModel,
        cryptoType: MultiassetCryptoType
    ) -> ExtrinsicOperationFactoryProtocol {
        ExtrinsicOperationFactory(
            accountId: accountId,
            chain: chain,
            cryptoType: cryptoType,
            runtimeRegistry: runtimeRegistry,
            customExtensions: DefaultExtrinsicExtension.extensions,
            engine: engine
        )
    }

    func createSigningWrapper(
        metaId: String,
        account: ChainAccountResponse
    ) -> SigningWrapperProtocol {
        signingWrapperFactory.createSigningWrapper(for: metaId, accountResponse: account)
    }
}
