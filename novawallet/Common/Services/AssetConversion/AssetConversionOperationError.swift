import Foundation
import Operation_iOS

enum AssetConversionOperationError: Error {
    case remoteAssetNotFound(ChainAssetId)
    case runtimeError(String)
    case quoteCalcFailed
    case tradeDisabled
    case noRoutesAvailable
}
