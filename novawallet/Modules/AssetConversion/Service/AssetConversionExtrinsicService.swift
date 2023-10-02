import Foundation
import RobinHood

protocol AssetConversionExtrinsicServiceProtocol {
    func fetchExtrinsicBuilderClosure(
        for args: AssetConversion.CallArgs,
        codingFactory: RuntimeCoderFactoryProtocol
    ) -> ExtrinsicBuilderClosure
}

enum AssetConversionExtrinsicServiceError: Error {
    case remoteAssetNotFound(ChainAssetId)
}
