import RobinHood
import SoraKeystore
import SubstrateSdk

protocol ExtrinsicServiceFactoryProtocol {
    func createService(
        account: ChainAccountResponse,
        chain: ChainModel,
        extensions: [ExtrinsicExtension]
    ) -> ExtrinsicServiceProtocol

    func createOperationFactory(
        account: ChainAccountResponse,
        chain: ChainModel,
        extensions: [ExtrinsicExtension]
    ) -> ExtrinsicOperationFactoryProtocol
}

extension ExtrinsicServiceFactoryProtocol {
    func createService(
        account: ChainAccountResponse,
        chain: ChainModel
    ) -> ExtrinsicServiceProtocol {
        createService(
            account: account,
            chain: chain,
            extensions: DefaultExtrinsicExtension.extensions()
        )
    }

    func createService(
        account: ChainAccountResponse,
        chain: ChainModel,
        feeAssetConversionId: AssetConversionPallet.AssetId
    ) -> ExtrinsicServiceProtocol {
        createService(
            account: account,
            chain: chain,
            extensions: DefaultExtrinsicExtension.extensions(payingFeeIn: feeAssetConversionId)
        )
    }

    func createOperationFactory(
        account: ChainAccountResponse,
        chain: ChainModel
    ) -> ExtrinsicOperationFactoryProtocol {
        createOperationFactory(
            account: account,
            chain: chain,
            extensions: DefaultExtrinsicExtension.extensions()
        )
    }

    func createOperationFactory(
        account: ChainAccountResponse,
        chain: ChainModel,
        feeAssetConversionId: AssetConversionPallet.AssetId
    ) -> ExtrinsicOperationFactoryProtocol {
        createOperationFactory(
            account: account,
            chain: chain,
            extensions: DefaultExtrinsicExtension.extensions(payingFeeIn: feeAssetConversionId)
        )
    }
}

final class ExtrinsicServiceFactory {
    private let runtimeRegistry: RuntimeCodingServiceProtocol
    private let engine: JSONRPCEngine
    private let operationManager: OperationManagerProtocol
    private let userStorageFacade: StorageFacadeProtocol

    init(
        runtimeRegistry: RuntimeCodingServiceProtocol,
        engine: JSONRPCEngine,
        operationManager: OperationManagerProtocol,
        userStorageFacade: StorageFacadeProtocol
    ) {
        self.runtimeRegistry = runtimeRegistry
        self.engine = engine
        self.operationManager = operationManager
        self.userStorageFacade = userStorageFacade
    }
}

extension ExtrinsicServiceFactory: ExtrinsicServiceFactoryProtocol {
    func createService(
        account: ChainAccountResponse,
        chain: ChainModel,
        extensions: [ExtrinsicExtension]
    ) -> ExtrinsicServiceProtocol {
        let senderResolvingFactory = ExtrinsicSenderResolutionFactory(
            chainAccount: account,
            chain: chain,
            userStorageFacade: userStorageFacade
        )

        return ExtrinsicService(
            accountId: account.accountId,
            chain: chain,
            cryptoType: account.cryptoType,
            walletType: account.type,
            runtimeRegistry: runtimeRegistry,
            senderResolvingFactory: senderResolvingFactory,
            extensions: extensions,
            engine: engine,
            operationManager: operationManager
        )
    }

    func createOperationFactory(
        account: ChainAccountResponse,
        chain: ChainModel,
        extensions: [ExtrinsicExtension]
    ) -> ExtrinsicOperationFactoryProtocol {
        let senderResolvingFactory = ExtrinsicSenderResolutionFactory(
            chainAccount: account,
            chain: chain,
            userStorageFacade: userStorageFacade
        )

        return ExtrinsicOperationFactory(
            accountId: account.accountId,
            chain: chain,
            cryptoType: account.cryptoType,
            signaturePayloadFormat: account.type.signaturePayloadFormat,
            runtimeRegistry: runtimeRegistry,
            customExtensions: extensions,
            engine: engine,
            senderResolvingFactory: senderResolvingFactory,
            operationManager: operationManager
        )
    }
}
