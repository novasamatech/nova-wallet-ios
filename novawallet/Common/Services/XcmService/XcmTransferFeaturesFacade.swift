import Foundation
import Operation_iOS

protocol XcmTransferFeaturesFacadeProtocol {
    func createFeaturesFactoryWrapper(
        for chainId: ChainModel.Id
    ) -> CompoundOperationWrapper<XcmTransferFeaturesFactoryProtocol>
}

final class XcmTransferFeaturesFacade {
    let xcmPaymentApi: XcmPaymentOperationFactoryProtocol

    init(chainRegistry: ChainRegistryProtocol, operationQueue: OperationQueue) {
        xcmPaymentApi = XcmPaymentOperationFactory(
            chainRegistry: chainRegistry,
            operationQueue: operationQueue
        )
    }
}

extension XcmTransferFeaturesFacade: XcmTransferFeaturesFacadeProtocol {
    func createFeaturesFactoryWrapper(
        for chainId: ChainModel.Id
    ) -> CompoundOperationWrapper<XcmTransferFeaturesFactoryProtocol> {
        let supportWrapper = xcmPaymentApi.hasSupportWrapper(for: chainId)

        let mapOperation = ClosureOperation<XcmTransferFeaturesFactoryProtocol> {
            let hasApiSupport = try supportWrapper.targetOperation.extractNoCancellableResultData()

            return XcmTransferFeaturesFactory(hasXcmPaymentApi: hasApiSupport)
        }

        mapOperation.addDependency(supportWrapper.targetOperation)

        return supportWrapper.insertingTail(operation: mapOperation)
    }
}
