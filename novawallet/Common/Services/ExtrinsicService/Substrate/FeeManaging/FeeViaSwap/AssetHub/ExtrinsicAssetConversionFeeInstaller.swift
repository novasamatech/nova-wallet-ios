import Foundation
import SubstrateSdk
import BigInt

enum ExtrinsicAssetConversionFeeInstallError: Error {
    case invalidAssetId
}

final class ExtrinsicAssetConversionFeeInstaller {
    let feeAsset: ChainAsset
    let tip: BigUInt

    init(feeAsset: ChainAsset, tip: BigUInt = 0) {
        self.feeAsset = feeAsset
        self.tip = tip
    }
}

extension ExtrinsicAssetConversionFeeInstaller: ExtrinsicFeeInstalling {
    func installingFeeSettings(
        to builder: ExtrinsicBuilderProtocol,
        coderFactory: RuntimeCoderFactoryProtocol
    ) throws -> ExtrinsicBuilderProtocol {
        guard
            let assetId = AssetHubTokensConverter.convertToMultilocation(
                chainAsset: feeAsset,
                codingFactory: coderFactory
            ) else {
            throw ExtrinsicAssetConversionFeeInstallError.invalidAssetId
        }

        return builder.adding(
            transactionExtension: AssetConversionTxPayment(
                tip: tip,
                assetId: assetId
            )
        )
    }
}
