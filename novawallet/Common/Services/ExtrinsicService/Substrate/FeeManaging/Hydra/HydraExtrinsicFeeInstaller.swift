import Foundation
import SubstrateSdk

final class HydraExtrinsicFeeInstaller {
    let feeAsset: ChainAsset
    let swapState: HydraDx.SwapRemoteState

    init(
        feeAsset: ChainAsset,
        swapState: HydraDx.SwapRemoteState
    ) {
        self.feeAsset = feeAsset
        self.swapState = swapState
    }
}

extension HydraExtrinsicFeeInstaller {
    struct FeeInstallingCalls {
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

        let calls = createFeeCalls(using: assetId)

        guard
            let setCurrencyCall = calls.setCurrencyCall,
            let revertCurrencyCall = calls.revertCurrencyCall
        else {
            return builder
        }

        return try builder
            .adding(call: setCurrencyCall.runtimeCall(), at: 0)
            .adding(call: revertCurrencyCall.runtimeCall())
    }

    private func createFeeCalls(using assetId: HydraDx.LocalRemoteAssetId) -> FeeInstallingCalls {
        let setCurrencyCall: HydraDx.SetCurrencyCall? = {
            let currentFeeAssetId = swapState.feeCurrency ?? HydraDx.nativeAssetId

            guard currentFeeAssetId != assetId.remoteAssetId else {
                return nil
            }

            return .init(currency: assetId.remoteAssetId)
        }()

        let revertCurrencyCall: HydraDx.SetCurrencyCall? = {
            guard assetId.remoteAssetId != HydraDx.nativeAssetId else {
                return nil
            }

            return .init(currency: HydraDx.nativeAssetId)
        }()

        return FeeInstallingCalls(setCurrencyCall: setCurrencyCall, revertCurrencyCall: revertCurrencyCall)
    }
}
