import Foundation
import RobinHood

protocol AssetConversionOperationFactoryProtocol {
    func availableDirections() -> CompoundOperationWrapper<[ChainAssetId: Set<ChainAssetId>]>
    func availableDirectionsForAsset(_ chainAssetId: ChainAssetId) -> CompoundOperationWrapper<Set<ChainAssetId>>
    func quote(for args: AssetConversion.Args) -> CompoundOperationWrapper<AssetConversion.Quote>
}

protocol AssetConversionServiceProtocol {
    func fetchExtrinsicBuilderClosure(for args: AssetConversion.Args) -> ExtrinsicBuilderClosure
}
