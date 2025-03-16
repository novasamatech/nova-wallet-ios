import Foundation
import Operation_iOS

protocol XcmCrosschainFeeCalculating {
    func crossChainFeeWrapper(
        request: XcmUnweightedTransferRequest,
        xcmTransfers: XcmLegacyTransfers
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
