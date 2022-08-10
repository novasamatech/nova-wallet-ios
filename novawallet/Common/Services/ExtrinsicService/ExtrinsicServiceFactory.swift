import RobinHood
import SoraKeystore
import SubstrateSdk

protocol ExtrinsicServiceFactoryProtocol {
    func createService(
        account: ChainAccountResponse,
        chain: ChainModel
    ) -> ExtrinsicServiceProtocol

    func createOperationFactory(
        account: ChainAccountResponse,
        chain: ChainModel
    ) -> ExtrinsicOperationFactoryProtocol
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
        account: ChainAccountResponse,
        chain: ChainModel
    ) -> ExtrinsicServiceProtocol {
        ExtrinsicService(
            accountId: account.accountId,
            chain: chain,
            cryptoType: account.cryptoType,
            walletType: account.type,
            runtimeRegistry: runtimeRegistry,
            engine: engine,
            operationManager: operationManager
        )
    }

    func createOperationFactory(
        account: ChainAccountResponse,
        chain: ChainModel
    ) -> ExtrinsicOperationFactoryProtocol {
        ExtrinsicOperationFactory(
            accountId: account.accountId,
            chain: chain,
            cryptoType: account.cryptoType,
            signaturePayloadFormat: account.type.signaturePayloadFormat,
            runtimeRegistry: runtimeRegistry,
            customExtensions: DefaultExtrinsicExtension.extensions,
            engine: engine
        )
    }
}
