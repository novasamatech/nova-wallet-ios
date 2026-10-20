import Foundation
import Operation_iOS
import SubstrateSdk

protocol ExtrinsicTimingServiceFactoryProtocol {
    func createService(
        account: ChainAccountResponse,
        chain: ChainModel,
        nonceOperationFactory: TransactionNonceOperationFactoryProtocol,
        eraOperationFactory: ExtrinsicEraOperationFactoryProtocol
    ) -> ExtrinsicServiceProtocol

    func createOperationFactory(
        account: ChainAccountResponse,
        chain: ChainModel,
        nonceOperationFactory: TransactionNonceOperationFactoryProtocol,
        eraOperationFactory: ExtrinsicEraOperationFactoryProtocol
    ) -> ExtrinsicOperationFactoryProtocol
}

extension ExtrinsicServiceFactory: ExtrinsicTimingServiceFactoryProtocol {
    func createService(
        account: ChainAccountResponse,
        chain: ChainModel,
        nonceOperationFactory: TransactionNonceOperationFactoryProtocol,
        eraOperationFactory: ExtrinsicEraOperationFactoryProtocol
    ) -> ExtrinsicServiceProtocol {
        ExtrinsicService(
            chain: chain,
            runtimeRegistry: runtimeRegistry,
            senderResolvingFactory: createSenderResolvingFactory(account: account, chain: chain),
            metadataHashOperationFactory: metadataHashOperationFactory,
            nonceOperationFactory: nonceOperationFactory,
            feeEstimationRegistry: createFeeEstimationRegistry(account: account, chain: chain),
            extensions: ExtrinsicSignedExtensionFacade().createFactory(for: chain.chainId).createExtensions(),
            engine: engine,
            operationManager: OperationManager(operationQueue: operationQueue),
            eraOperationFactory: eraOperationFactory
        )
    }

    func createOperationFactory(
        account: ChainAccountResponse,
        chain: ChainModel,
        nonceOperationFactory: TransactionNonceOperationFactoryProtocol,
        eraOperationFactory: ExtrinsicEraOperationFactoryProtocol
    ) -> ExtrinsicOperationFactoryProtocol {
        ExtrinsicOperationFactory(
            chain: chain,
            runtimeRegistry: runtimeRegistry,
            customExtensions: ExtrinsicSignedExtensionFacade().createFactory(for: chain.chainId).createExtensions(),
            engine: engine,
            feeEstimationRegistry: createFeeEstimationRegistry(account: account, chain: chain),
            metadataHashOperationFactory: metadataHashOperationFactory,
            nonceOperationFactory: nonceOperationFactory,
            senderResolvingFactory: createSenderResolvingFactory(account: account, chain: chain),
            eraOperationFactory: eraOperationFactory,
            blockHashOperationFactory: BlockHashOperationFactory(),
            operationManager: OperationManager(operationQueue: operationQueue)
        )
    }
}

private extension ExtrinsicServiceFactory {
    func createSenderResolvingFactory(
        account: ChainAccountResponse,
        chain: ChainModel
    ) -> ExtrinsicSenderResolutionFactoryProtocol {
        ExtrinsicSenderResolutionFactory(chainAccount: account, chain: chain, userStorageFacade: userStorageFacade)
    }

    func createFeeEstimationRegistry(
        account: ChainAccountResponse,
        chain: ChainModel
    ) -> ExtrinsicFeeEstimationRegistring {
        let extrinsicFeeHost = ExtrinsicFeeEstimatorHost(
            account: account,
            chain: chain,
            connection: engine,
            runtimeProvider: runtimeRegistry,
            userStorageFacade: userStorageFacade,
            substrateStorageFacade: substrateStorageFacade,
            operationQueue: operationQueue
        )

        return ExtrinsicFeeEstimationRegistry(
            chain: chain,
            estimatingWrapperFactory: ExtrinsicFeeEstimatingWrapperFactory(
                host: extrinsicFeeHost,
                customFeeEstimatorFactory: AssetConversionFeeEstimatingFactory(host: extrinsicFeeHost)
            ),
            feeInstallingWrapperFactory: AssetConversionFeeInstallingFactory(host: extrinsicFeeHost)
        )
    }
}
