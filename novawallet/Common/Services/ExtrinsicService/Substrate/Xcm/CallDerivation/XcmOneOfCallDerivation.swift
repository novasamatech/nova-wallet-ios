import Foundation
import Operation_iOS

final class XcmOneOfCallDerivator {
    let chainRegistry: ChainRegistryProtocol
    let operationQueue: OperationQueue

    private let featuresFacade: XcmTransferFeaturesFacadeProtocol

    init(chainRegistry: ChainRegistryProtocol, operationQueue: OperationQueue) {
        self.chainRegistry = chainRegistry
        self.operationQueue = operationQueue

        featuresFacade = XcmTransferFeaturesFacade(
            chainRegistry: chainRegistry,
            operationQueue: operationQueue
        )
    }
}

private extension XcmOneOfCallDerivator {
    func createCallDerivationWrapper(
        for transferRequest: XcmUnweightedTransferRequest,
        dependingOn featuresFactoryOperation: BaseOperation<XcmTransferFeaturesFactoryProtocol>
    ) -> CompoundOperationWrapper<RuntimeCallCollecting> {
        OperationCombiningService.compoundNonOptionalWrapper(
            operationQueue: operationQueue
        ) {
            let features = try featuresFactoryOperation.extractNoCancellableResultData().createFeatures(
                for: transferRequest.metadata
            )

            let actualDerivator: XcmCallDerivating = if features.shouldUseXcmExecute {
                XcmExecuteDerivator(
                    chainRegistry: self.chainRegistry,
                    xcmPaymentFactory: XcmPaymentOperationFactory(
                        chainRegistry: self.chainRegistry,
                        operationQueue: self.operationQueue
                    ),
                    metadataFactory: XcmPalletMetadataQueryFactory()
                )
            } else {
                XcmTypeBasedCallDerivator(chainRegistry: self.chainRegistry)
            }

            return actualDerivator.createTransferCallDerivationWrapper(for: transferRequest)
        }
    }
}

extension XcmOneOfCallDerivator: XcmCallDerivating {
    func createTransferCallDerivationWrapper(
        for transferRequest: XcmUnweightedTransferRequest
    ) -> CompoundOperationWrapper<RuntimeCallCollecting> {
        let featuresFactoryWrapper = featuresFacade.createFeaturesFactoryWrapper(
            for: transferRequest.originChain.chainId
        )

        let derivationWrapper = createCallDerivationWrapper(
            for: transferRequest,
            dependingOn: featuresFactoryWrapper.targetOperation
        )

        derivationWrapper.addDependency(wrapper: featuresFactoryWrapper)

        return derivationWrapper.insertingHead(operations: featuresFactoryWrapper.allOperations)
    }
}
