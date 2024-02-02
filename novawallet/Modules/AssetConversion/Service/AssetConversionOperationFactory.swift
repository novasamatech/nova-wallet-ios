import Foundation
import RobinHood

enum AssetConversionOperationError: Error {
    case remoteAssetNotFound(ChainAssetId)
    case runtimeError(String)
    case quoteCalcFailed
}
