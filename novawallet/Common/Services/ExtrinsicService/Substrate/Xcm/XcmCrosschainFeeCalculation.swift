import Foundation
import Operation_iOS

protocol XcmCrosschainFeeCalculating {
    func destinationExecutionFeeWrapper(
        request: XcmUnweightedTransferRequest,
        xcmTransfers: XcmTransfers
    ) -> CompoundOperationWrapper<XcmFeeModelProtocol>

    func reserveExecutionFeeWrapper(
        request: XcmUnweightedTransferRequest,
        xcmTransfers: XcmTransfers
    ) -> CompoundOperationWrapper<XcmFeeModelProtocol>

    func crossChainFeeWrapper(
        request: XcmUnweightedTransferRequest,
        xcmTransfers: XcmTransfers
    ) -> CompoundOperationWrapper<XcmFeeModelProtocol>
}

enum XcmCrosschainFeeCalculatorError: Error {
    case reserveFeeNotAvailable
    case noArgumentFound(String)
    case deliveryFeeNotAvailable
    case noDestinationFee(origin: ChainAssetId, destination: ChainModel.Id)
    case noReserveFee(ChainAssetId)
    case noBaseWeight(ChainModel.Id)
}
