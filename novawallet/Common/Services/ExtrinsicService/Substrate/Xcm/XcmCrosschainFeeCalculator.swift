import Foundation
import Operation_iOS

final class XcmCrosschainFeeCalculator {
    let legacyCalculator: XcmCrosschainFeeCalculating
    let dynamicCalculator: XcmCrosschainFeeCalculating

    init(
        chainRegistry: ChainRegistryProtocol,
        callDerivator: XcmCallDerivating,
        operationQueue: OperationQueue,
        wallet: MetaAccountModel,
        userStorageFacade: StorageFacadeProtocol,
        substrateStorageFacade: StorageFacadeProtocol,
        customFeeEstimatingFactory: ExtrinsicCustomFeeEstimatingFactoryProtocol?,
        logger: LoggerProtocol
    ) {
        legacyCalculator = XcmLegacyCrosschainFeeCalculator(
            chainRegistry: chainRegistry,
            operationQueue: operationQueue,
            wallet: wallet,
            userStorageFacade: userStorageFacade,
            substrateStorageFacade: substrateStorageFacade,
            customFeeEstimatingFactory: customFeeEstimatingFactory
        )

        dynamicCalculator = XcmDynamicCrosschainFeeCalculator(
            chainRegistry: chainRegistry,
            callDerivator: callDerivator,
            operationQueue: operationQueue,
            logger: logger
        )
    }
}

extension XcmCrosschainFeeCalculator: XcmCrosschainFeeCalculating {
    func crossChainFeeWrapper(
        request: XcmUnweightedTransferRequest
    ) -> CompoundOperationWrapper<XcmFeeModelProtocol> {
        switch request.metadata.fee {
        case .legacy:
            return legacyCalculator.crossChainFeeWrapper(request: request)
        case .dynamic:
            return dynamicCalculator.crossChainFeeWrapper(request: request)
        }
    }
}
