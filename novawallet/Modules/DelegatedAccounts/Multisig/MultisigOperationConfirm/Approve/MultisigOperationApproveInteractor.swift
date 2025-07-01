import Foundation
import Operation_iOS

final class MultisigOperationApproveInteractor: MultisigOperationConfirmInteractor {
    let callWeightEstimator: CallWeightEstimatingFactoryProtocol

    private var callWeight: Substrate.Weight?
    private var callCollector: RuntimeCallCollecting?

    init(
        operation: Multisig.PendingOperation,
        chain: ChainModel,
        multisigWallet: MetaAccountModel,
        signatoryRepository: MultisigSignatoryRepositoryProtocol,
        pendingMultisigLocalSubscriptionFactory: MultisigOperationsLocalSubscriptionFactoryProtocol,
        extrinsicServiceFactory: ExtrinsicServiceFactoryProtocol,
        signingWrapperFactory: SigningWrapperFactoryProtocol,
        chainRegistry: ChainRegistryProtocol,
        callWeightEstimator: CallWeightEstimatingFactoryProtocol,
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) {
        self.callWeightEstimator = callWeightEstimator

        super.init(
            operation: operation,
            chain: chain,
            multisigWallet: multisigWallet,
            signatoryRepository: signatoryRepository,
            pendingMultisigLocalSubscriptionFactory: pendingMultisigLocalSubscriptionFactory,
            extrinsicServiceFactory: extrinsicServiceFactory,
            signingWrapperFactory: signingWrapperFactory,
            chainRegistry: chainRegistry,
            operationQueue: operationQueue,
            logger: logger
        )
    }
}

private extension MultisigOperationApproveInteractor {
    func fetchCallWeight(with _: @escaping (Result<Substrate.Weight, Error>) -> Void) {}
}
