import RobinHood
import SoraKeystore
import SubstrateSdk

protocol ExtrinsicServiceFactoryProtocol {
    func createService(
        account: ChainAccountResponse,
        chain: ChainModel,
        extensions: [ExtrinsicSignedExtending]
    ) -> ExtrinsicServiceProtocol

    func createOperationFactory(
        account: ChainAccountResponse,
        chain: ChainModel,
        extensions: [ExtrinsicSignedExtending]
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
            extensions: ExtrinsicSignedExtensionFacade().createFactory(for: chain.chainId).createExtensions()
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
            extensions: ExtrinsicSignedExtensionFacade().createFactory(for: chain.chainId).createExtensions(
                payingFeeIn: feeAssetConversionId
            )
        )
    }

    func createOperationFactory(
        account: ChainAccountResponse,
        chain: ChainModel
    ) -> ExtrinsicOperationFactoryProtocol {
        createOperationFactory(
            account: account,
            chain: chain,
            extensions: ExtrinsicSignedExtensionFacade().createFactory(for: chain.chainId).createExtensions()
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
            extensions: ExtrinsicSignedExtensionFacade().createFactory(for: chain.chainId).createExtensions(
                payingFeeIn: feeAssetConversionId
            )
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
        extensions: [ExtrinsicSignedExtending]
    ) -> ExtrinsicServiceProtocol {
        let senderResolvingFactory = ExtrinsicSenderResolutionFactory(
            chainAccount: account,
            chain: chain,
            userStorageFacade: userStorageFacade
        )

        return ExtrinsicService(
            chain: chain,
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
        extensions: [ExtrinsicSignedExtending]
    ) -> ExtrinsicOperationFactoryProtocol {
        let senderResolvingFactory = ExtrinsicSenderResolutionFactory(
            chainAccount: account,
            chain: chain,
            userStorageFacade: userStorageFacade
        )

        return ExtrinsicOperationFactory(
            chain: chain,
            runtimeRegistry: runtimeRegistry,
            customExtensions: extensions,
            engine: engine,
            senderResolvingFactory: senderResolvingFactory,
            operationManager: operationManager
        )
    }
}
