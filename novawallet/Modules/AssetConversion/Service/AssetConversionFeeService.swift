import Foundation
import BigInt

extension AssetConversion {
    struct AmountWithNative {
        let targetAmount: BigUInt
        let nativeAmouunt: BigUInt
    }

    struct FeeModel {
        let totalFee: AmountWithNative
        let networkFeeAddition: AmountWithNative?
    }

    typealias FeeResult = Result<AssetConversion.FeeModel, AssetConversionFeeServiceError>
}

typealias AssetConversionFeeServiceClosure = (AssetConversion.FeeResult) -> Void

protocol AssetConversionFeeServiceProtocol {
    func calculate(
        in asset: ChainAsset,
        callArgs: AssetConversion.CallArgs,
        runCompletionIn queue: DispatchQueue,
        completion closure: @escaping AssetConversionFeeServiceClosure
    )
}

enum AssetConversionFeeServiceError: Error {
    case accountMissing
    case chainRuntimeMissing
    case chainConnectionMissing
    case utilityAssetMissing
    case setupFailed(String)
    case calculationFailed(String)
}
