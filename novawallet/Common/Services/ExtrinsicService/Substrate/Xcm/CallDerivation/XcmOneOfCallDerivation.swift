import Foundation
import Operation_iOS

final class XcmOneOfCallDerivator {
    let chainRegistry: ChainRegistryProtocol
    let operationQueue: OperationQueue

    init(chainRegistry: ChainRegistryProtocol, operationQueue: OperationQueue) {
        self.chainRegistry = chainRegistry
        self.operationQueue = operationQueue
    }
}

extension XcmOneOfCallDerivator: XcmCallDerivating {
    func createTransferCallDerivationWrapper(
        for transferRequest: XcmUnweightedTransferRequest
    ) -> CompoundOperationWrapper<RuntimeCallCollecting> {
        let actualDerivator: XcmCallDerivating = if transferRequest.metadata.supportsXcmExecute {
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
