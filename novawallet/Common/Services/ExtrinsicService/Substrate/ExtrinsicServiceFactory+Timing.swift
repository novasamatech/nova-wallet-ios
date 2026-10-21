import Foundation
import Operation_iOS
import SubstrateSdk

protocol ExtrinsicTimingServiceFactoryProtocol {
    func createOperationFactory(
        account: ChainAccountResponse,
        chain: ChainModel,
        nonceOperationFactory: TransactionNonceOperationFactoryProtocol,
        eraOperationFactory: ExtrinsicEraOperationFactoryProtocol
    ) -> ExtrinsicOperationFactoryProtocol
}

extension ExtrinsicServiceFactory: ExtrinsicTimingServiceFactoryProtocol {
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
