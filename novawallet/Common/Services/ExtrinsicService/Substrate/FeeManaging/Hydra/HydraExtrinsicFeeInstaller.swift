import Foundation
import SubstrateSdk

final class HydraExtrinsicFeeInstaller {
    let feeAsset: ChainAsset

    init(feeAsset: ChainAsset) {
        self.feeAsset = feeAsset
    }
}

extension HydraExtrinsicFeeInstaller: ExtrinsicFeeInstalling {
    func installingFeeSettings(
        to builder: ExtrinsicBuilderProtocol,
        coderFactory: RuntimeCoderFactoryProtocol
    ) throws -> ExtrinsicBuilderProtocol {
        let assetId = try HydraDxTokenConverter.convertToRemote(
            chainAsset: feeAsset,
            codingFactory: coderFactory
        )

        // set

        let shouldSetCurrency = feeAsset.chain.utilityAsset()?.assetId != feeAsset.asset.assetId

        let setCurrencyCall: HydraDx.SetCurrencyCall? = {
            guard shouldSetCurrency else { return nil }

            return .init(currency: assetId.remoteAssetId)
        }()

        // revert

        let shouldRevertCurrency = feeAsset.asset.assetId != HydraDx.nativeAssetId

        let revertCurrencyCall: HydraDx.SetCurrencyCall? = {
            guard shouldRevertCurrency else { return nil }

            return .init(currency: HydraDx.nativeAssetId)
        }()

        var mutBuilder = builder

        if let setCurrencyCall, let revertCurrencyCall {
            mutBuilder = try builder
                .with(batchType: .ignoreFails)
                .adding(call: setCurrencyCall.runtimeCall(), at: 0)
                .adding(call: revertCurrencyCall.runtimeCall())
        }

        return mutBuilder
    }
}
