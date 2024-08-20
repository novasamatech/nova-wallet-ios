import Foundation
import SubstrateSdk

final class HydraExtrinsicFeeInstaller {
    let feeAsset: ChainAsset

    init(feeAsset: ChainAsset) {
        self.feeAsset = feeAsset
    }
}

extension HydraExtrinsicFeeInstaller {
    struct TransferFeeInstallingCalls {
        let setCurrencyCall: HydraDx.SetCurrencyCall?
        let revertCurrencyCall: HydraDx.SetCurrencyCall?
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

        let calls = createTransferFeeCalls(using: assetId)

        guard
            let setCurrencyCall = calls.setCurrencyCall,
            let revertCurrencyCall = calls.revertCurrencyCall
        else {
            return builder
        }

        return try builder
            .with(batchType: .ignoreFails)
            .adding(call: setCurrencyCall.runtimeCall(), at: 0)
            .adding(call: revertCurrencyCall.runtimeCall())
    }

    private func createTransferFeeCalls(using assetId: HydraDx.LocalRemoteAssetId) -> TransferFeeInstallingCalls {
        let shouldSetCurrency = feeAsset.asset.assetId != HydraDx.nativeAssetId

        let (setCurrencyCall, revertCurrencyCall): (HydraDx.SetCurrencyCall?, HydraDx.SetCurrencyCall?) = {
            guard shouldSetCurrency else { return (nil, nil) }

            return (
                .init(currency: assetId.remoteAssetId),
                .init(currency: HydraDx.nativeAssetId)
            )
        }()

        return TransferFeeInstallingCalls(
            setCurrencyCall: setCurrencyCall,
            revertCurrencyCall: revertCurrencyCall
        )
    }
}
