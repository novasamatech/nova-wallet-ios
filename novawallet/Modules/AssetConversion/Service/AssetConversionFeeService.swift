import Foundation
import BigInt

extension AssetConversion {
    struct AmountWithNative {
        let targetAmount: BigUInt
        let nativeAmount: BigUInt
    }

    struct FeeModel {
        let totalFee: AmountWithNative
        let networkFeeAddition: AmountWithNative?

        var networkFee: AmountWithNative {
            guard let addition = networkFeeAddition else {
                return totalFee
            }

            let feeInTargetToken = totalFee.targetAmount >= addition.targetAmount ?
                totalFee.targetAmount - addition.targetAmount : totalFee.targetAmount

            let feeInNativeToken = totalFee.nativeAmount >= addition.nativeAmount ?
                totalFee.nativeAmount - addition.nativeAmount : totalFee.nativeAmount

            return .init(targetAmount: feeInTargetToken, nativeAmount: feeInNativeToken)
        }
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
