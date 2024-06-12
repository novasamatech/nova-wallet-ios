import Foundation
import Operation_iOS

protocol AssetConversionExtrinsicServiceProtocol {
    func submit(
        callArgs: AssetConversion.CallArgs,
        feeAsset: ChainAsset,
        signer: SigningWrapperProtocol,
        runCompletionIn queue: DispatchQueue,
        completion closure: @escaping ExtrinsicSubmitClosure
    )
}

enum AssetConversionExtrinsicServiceError: Error {
    case remoteAssetNotFound(ChainAssetId)
}

protocol AssetConversionCallPathFactoryProtocol {
    func createHistoryCallPath(for args: AssetConversion.CallArgs) -> CallCodingPath
}
