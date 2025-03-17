import Operation_iOS
import SoraKeystore
import SubstrateSdk

protocol ExtrinsicServiceFactoryProtocol {
    func createService(
        account: ChainAccountResponse,
        chain: ChainModel,
        extensions: [ExtrinsicSignedExtending]
    ) -> ExtrinsicServiceProtocol

    func createService(
        account: ChainAccountResponse,
        chain: ChainModel,
        extensions: [ExtrinsicSignedExtending],
        customFeeEstimatingFactory: ExtrinsicCustomFeeEstimatingFactoryProtocol
    ) -> ExtrinsicServiceProtocol

    func createOperationFactory(
        account: ChainAccountResponse,
        chain: ChainModel,
        extensions: [ExtrinsicSignedExtending]
    ) -> ExtrinsicOperationFactoryProtocol

    func createOperationFactory(
        account: ChainAccountResponse,
        chain: ChainModel,
        extensions: [ExtrinsicSignedExtending],
        customFeeEstimatingFactory: ExtrinsicCustomFeeEstimatingFactoryProtocol
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
        customFeeEstimatingFactory: ExtrinsicCustomFeeEstimatingFactoryProtocol
    ) -> ExtrinsicServiceProtocol {
        createService(
            account: account,
            chain: chain,
            extensions: ExtrinsicSignedExtensionFacade().createFactory(for: chain.chainId).createExtensions(),
            customFeeEstimatingFactory: customFeeEstimatingFactory
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
        customFeeEstimatingFactory: ExtrinsicCustomFeeEstimatingFactoryProtocol
    ) -> ExtrinsicOperationFactoryProtocol {
        createOperationFactory(
            account: account,
            chain: chain,
            extensions: ExtrinsicSignedExtensionFacade().createFactory(for: chain.chainId).createExtensions(),
            customFeeEstimatingFactory: customFeeEstimatingFactory
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
    private let runtimeRegistry: RuntimeProviderProtocol
    private let engine: JSONRPCEngine
    private let operationQueue: OperationQueue
    private let userStorageFacade: StorageFacadeProtocol
    private let substrateStorageFacade: StorageFacadeProtocol
    private let metadataHashOperationFactory: MetadataHashOperationFactoryProtocol

    init(
        runtimeRegistry: RuntimeProviderProtocol,
        engine: JSONRPCEngine,
        operationQueue: OperationQueue,
        userStorageFacade: StorageFacadeProtocol,
        substrateStorageFacade: StorageFacadeProtocol
    ) {
        self.runtimeRegistry = runtimeRegistry
        self.engine = engine

        metadataHashOperationFactory = MetadataHashOperationFactory(
            metadataRepositoryFactory: RuntimeMetadataRepositoryFactory(storageFacade: substrateStorageFacade),
            operationQueue: operationQueue
        )

        self.operationQueue = operationQueue
        self.userStorageFacade = userStorageFacade
        self.substrateStorageFacade = substrateStorageFacade
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

        let extrinsicFeeHost = ExtrinsicFeeEstimatorHost(
            account: account,
            chain: chain,
            connection: engine,
            runtimeProvider: runtimeRegistry,
            userStorageFacade: userStorageFacade,
            substrateStorageFacade: substrateStorageFacade,
            operationQueue: operationQueue
        )

        let feeEstimationRegistry = ExtrinsicFeeEstimationRegistry(
            chain: chain,
            estimatingWrapperFactory: ExtrinsicFeeEstimatingWrapperFactory(
                host: extrinsicFeeHost,
                customFeeEstimatorFactory: AssetConversionFeeEstimatingFactory(host: extrinsicFeeHost)
            ),
            feeInstallingWrapperFactory: AssetConversionFeeInstallingFactory(host: extrinsicFeeHost)
        )

        return ExtrinsicService(
            chain: chain,
            runtimeRegistry: runtimeRegistry,
            senderResolvingFactory: senderResolvingFactory,
            metadataHashOperationFactory: metadataHashOperationFactory,
            feeEstimationRegistry: feeEstimationRegistry,
            extensions: extensions,
            engine: engine,
            operationManager: OperationManager(operationQueue: operationQueue)
        )
    }

    func createService(
        account: ChainAccountResponse,
        chain: ChainModel,
        extensions: [ExtrinsicSignedExtending],
        customFeeEstimatingFactory: ExtrinsicCustomFeeEstimatingFactoryProtocol
    ) -> ExtrinsicServiceProtocol {
        let senderResolvingFactory = ExtrinsicSenderResolutionFactory(
            chainAccount: account,
            chain: chain,
            userStorageFacade: userStorageFacade
        )

        let extrinsicFeeHost = ExtrinsicFeeEstimatorHost(
            account: account,
            chain: chain,
            connection: engine,
            runtimeProvider: runtimeRegistry,
            userStorageFacade: userStorageFacade,
            substrateStorageFacade: substrateStorageFacade,
            operationQueue: operationQueue
        )

        let feeEstimationRegistry = ExtrinsicFeeEstimationRegistry(
            chain: chain,
            estimatingWrapperFactory: ExtrinsicFeeEstimatingWrapperFactory(
                host: extrinsicFeeHost,
                customFeeEstimatorFactory: customFeeEstimatingFactory
            ),
            feeInstallingWrapperFactory: AssetConversionFeeInstallingFactory(host: extrinsicFeeHost)
        )

        return ExtrinsicService(
            chain: chain,
            runtimeRegistry: runtimeRegistry,
            senderResolvingFactory: senderResolvingFactory,
            metadataHashOperationFactory: metadataHashOperationFactory,
            feeEstimationRegistry: feeEstimationRegistry,
            extensions: extensions,
            engine: engine,
            operationManager: OperationManager(operationQueue: operationQueue)
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

        let extrinsicFeeHost = ExtrinsicFeeEstimatorHost(
            account: account,
            chain: chain,
            connection: engine,
            runtimeProvider: runtimeRegistry,
            userStorageFacade: userStorageFacade,
            substrateStorageFacade: substrateStorageFacade,
            operationQueue: operationQueue
        )

        let feeEstimationRegistry = ExtrinsicFeeEstimationRegistry(
            chain: chain,
            estimatingWrapperFactory: ExtrinsicFeeEstimatingWrapperFactory(
                host: extrinsicFeeHost,
                customFeeEstimatorFactory: AssetConversionFeeEstimatingFactory(host: extrinsicFeeHost)
            ),
            feeInstallingWrapperFactory: AssetConversionFeeInstallingFactory(host: extrinsicFeeHost)
        )

        return ExtrinsicOperationFactory(
            chain: chain,
            runtimeRegistry: runtimeRegistry,
            customExtensions: extensions,
            engine: engine,
            feeEstimationRegistry: feeEstimationRegistry,
            metadataHashOperationFactory: metadataHashOperationFactory,
            senderResolvingFactory: senderResolvingFactory,
            blockHashOperationFactory: BlockHashOperationFactory(),
            operationManager: OperationManager(operationQueue: operationQueue)
        )
    }

    func createOperationFactory(
        account: ChainAccountResponse,
        chain: ChainModel,
        extensions: [ExtrinsicSignedExtending],
        customFeeEstimatingFactory: ExtrinsicCustomFeeEstimatingFactoryProtocol
    ) -> ExtrinsicOperationFactoryProtocol {
        let senderResolvingFactory = ExtrinsicSenderResolutionFactory(
            chainAccount: account,
            chain: chain,
            userStorageFacade: userStorageFacade
        )

        let extrinsicFeeHost = ExtrinsicFeeEstimatorHost(
            account: account,
            chain: chain,
            connection: engine,
            runtimeProvider: runtimeRegistry,
            userStorageFacade: userStorageFacade,
            substrateStorageFacade: substrateStorageFacade,
            operationQueue: operationQueue
        )

        let feeEstimationRegistry = ExtrinsicFeeEstimationRegistry(
            chain: chain,
            estimatingWrapperFactory: ExtrinsicFeeEstimatingWrapperFactory(
                host: extrinsicFeeHost,
                customFeeEstimatorFactory: customFeeEstimatingFactory
            ),
            feeInstallingWrapperFactory: AssetConversionFeeInstallingFactory(host: extrinsicFeeHost)
        )

        return ExtrinsicOperationFactory(
            chain: chain,
            runtimeRegistry: runtimeRegistry,
            customExtensions: extensions,
            engine: engine,
            feeEstimationRegistry: feeEstimationRegistry,
            metadataHashOperationFactory: metadataHashOperationFactory,
            senderResolvingFactory: senderResolvingFactory,
            blockHashOperationFactory: BlockHashOperationFactory(),
            operationManager: OperationManager(operationQueue: operationQueue)
        )
    }
}
