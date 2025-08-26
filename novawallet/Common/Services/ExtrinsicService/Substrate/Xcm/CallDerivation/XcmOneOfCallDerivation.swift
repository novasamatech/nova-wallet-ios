import Foundation
import Operation_iOS

final class XcmOneOfCallDerivator {
    let chainRegistry: ChainRegistryProtocol
    let operationQueue: OperationQueue

    private let featuresFactory = XcmTransferFeaturesFactory()

    init(chainRegistry: ChainRegistryProtocol, operationQueue: OperationQueue) {
        self.chainRegistry = chainRegistry
        self.operationQueue = operationQueue
    }
}

private extension XcmOneOfCallDerivator {
    func createCallDerivationWrapper(
        for transferRequest: XcmUnweightedTransferRequest
    ) -> CompoundOperationWrapper<RuntimeCallCollecting> {
        let features = featuresFactory.createFeatures(for: transferRequest.metadata)

        let actualDerivator: XcmCallDerivating = if features.shouldUseXcmExecute {
            XcmExecuteDerivator(
                chainRegistry: chainRegistry,
                xcmPaymentFactory: XcmPaymentOperationFactory(
                    chainRegistry: chainRegistry,
                    operationQueue: operationQueue
                ),
                metadataFactory: XcmPalletMetadataQueryFactory()
            )
        } else {
            XcmTypeBasedCallDerivator(chainRegistry: chainRegistry)
        }

        return actualDerivator.createTransferCallDerivationWrapper(for: transferRequest)
    }
}

extension XcmOneOfCallDerivator: XcmCallDerivating {
    func createTransferCallDerivationWrapper(
        for transferRequest: XcmUnweightedTransferRequest
    ) -> CompoundOperationWrapper<RuntimeCallCollecting> {
        createCallDerivationWrapper(for: transferRequest)
    }
}
