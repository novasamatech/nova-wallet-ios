import Foundation
import RobinHood

protocol AssetConversionOperationFactoryProtocol {
    func availableDirections() -> CompoundOperationWrapper<[ChainAssetId: Set<ChainAssetId>]>
    func availableDirectionsForAsset(_ chainAssetId: ChainAssetId) -> CompoundOperationWrapper<Set<ChainAssetId>>
    func quote(for args: AssetConversion.QuoteArgs) -> CompoundOperationWrapper<AssetConversion.Quote>
}

enum AssetConversionOperationError: Error {
    case remoteAssetNotFound(ChainAssetId)
    case runtimeError(String)
    case quoteCalcFailed
}
