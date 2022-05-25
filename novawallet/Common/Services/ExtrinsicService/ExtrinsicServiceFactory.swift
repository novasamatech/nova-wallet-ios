import RobinHood
import SoraKeystore
import SubstrateSdk

protocol ExtrinsicServiceFactoryProtocol {
    func createService(
        accountId: AccountId,
        chain: ChainModel,
        cryptoType: MultiassetCryptoType
    ) -> ExtrinsicServiceProtocol

    func createSigningWrapper(
        metaId: String,
        account: ChainAccountResponse
    ) -> SigningWrapperProtocol
}

final class ExtrinsicServiceFactory {
    private let runtimeRegistry: RuntimeCodingServiceProtocol
    private let engine: JSONRPCEngine
    private let operationManager: OperationManagerProtocol

    init(
        runtimeRegistry: RuntimeCodingServiceProtocol,
        engine: JSONRPCEngine,
        operationManager: OperationManagerProtocol
    ) {
        self.runtimeRegistry = runtimeRegistry
        self.engine = engine
        self.operationManager = operationManager
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

    func createSigningWrapper(
        metaId: String,
        account: ChainAccountResponse
    ) -> SigningWrapperProtocol {
        SigningWrapper(
            keystore: Keychain(),
            metaId: metaId,
            accountResponse: account
        )
    }
}
