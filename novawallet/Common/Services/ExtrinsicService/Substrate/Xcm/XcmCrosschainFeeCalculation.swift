import Foundation
import Operation_iOS

protocol XcmCrosschainFeeCalculating {
    func crossChainFeeWrapper(
        request: XcmUnweightedTransferRequest
    ) -> CompoundOperationWrapper<XcmFeeModelProtocol>
}

enum XcmCrosschainFeeCalculatorError: Error {
    case reserveFeeNotAvailable
    case noArgumentFound(String)
}
