import Foundation
import BigInt

extension AssetConversion {
    struct AmountWithNative: Equatable {
        let targetAmount: BigUInt
        let nativeAmount: BigUInt
    }

    struct FeeModel: Equatable {
        let totalFee: AmountWithNative
        let networkFee: AmountWithNative
        let networkFeePayer: ExtrinsicFeePayer?

        var networkNativeFeeAddition: AmountWithNative? {
            let targetAmount = totalFee.targetAmount > networkFee.targetAmount ?
                totalFee.targetAmount - networkFee.targetAmount : 0

            guard targetAmount > 0 else {
                return nil
            }

            let nativeAmount = totalFee.nativeAmount > networkFee.nativeAmount ?
                totalFee.nativeAmount - networkFee.nativeAmount : 0

            return .init(targetAmount: targetAmount, nativeAmount: nativeAmount)
        }

        var extrinsicFee: ExtrinsicFeeProtocol {
            ExtrinsicFee(amount: networkFee.targetAmount, payer: networkFeePayer, weight: 0)
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
    case feeAssetConversionFailed
    case setupFailed(String)
    case calculationFailed(String)
}
