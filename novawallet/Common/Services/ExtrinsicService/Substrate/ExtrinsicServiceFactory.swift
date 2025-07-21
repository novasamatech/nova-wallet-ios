import Operation_iOS
import Keystore_iOS
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

    func createExtrinsicSubmissionMonitor(
        with extrinsicService: ExtrinsicServiceProtocol
    ) -> ExtrinsicSubmitMonitorFactoryProtocol
}

extension ExtrinsicServiceFactoryProtocol {
    func createOperationFactoryForWeightEstimation(
        on chain: ChainModel
    ) -> ExtrinsicOperationFactoryProtocol {
        let accountId = AccountId.zeroAccountId(of: chain.accountIdSize)

        // we need an account with the type that prevents call override
        let account = ChainAccountResponse(
            metaId: UUID().uuidString,
            chainId: chain.chainId,
            accountId: accountId,
            publicKey: accountId,
            name: "",
            cryptoType: .sr25519,
            addressPrefix: chain.addressPrefix,
            isEthereumBased: chain.isEthereumBased,
            isChainAccount: false,
            type: .watchOnly
        )

        return createOperationFactory(account: account, chain: chain)
    }

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
    private let nonceOperationFactory = TransactionNonceOperationFactory()
    private let logger: LoggerProtocol

    init(
        runtimeRegistry: RuntimeProviderProtocol,
        engine: JSONRPCEngine,
        operationQueue: OperationQueue,
        userStorageFacade: StorageFacadeProtocol,
        substrateStorageFacade: StorageFacadeProtocol,
        logger: LoggerProtocol = Logger.shared
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
        self.logger = logger
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
            nonceOperationFactory: nonceOperationFactory,
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
            nonceOperationFactory: nonceOperationFactory,
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
            nonceOperationFactory: nonceOperationFactory,
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
            nonceOperationFactory: nonceOperationFactory,
            senderResolvingFactory: senderResolvingFactory,
            blockHashOperationFactory: BlockHashOperationFactory(),
            operationManager: OperationManager(operationQueue: operationQueue)
        )
    }

    func createExtrinsicSubmissionMonitor(
        with extrinsicService: ExtrinsicServiceProtocol
    ) -> ExtrinsicSubmitMonitorFactoryProtocol {
        let statusService = ExtrinsicStatusService(
            connection: engine,
            runtimeProvider: runtimeRegistry,
            eventsQueryFactory: BlockEventsQueryFactory(operationQueue: operationQueue),
            logger: logger
        )

        return ExtrinsicSubmissionMonitorFactory(
            submissionService: extrinsicService,
            statusService: statusService,
            operationQueue: operationQueue
        )
    }
}
