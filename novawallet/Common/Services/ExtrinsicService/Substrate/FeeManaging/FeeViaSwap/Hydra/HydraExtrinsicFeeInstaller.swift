import Foundation
import SubstrateSdk

final class HydraExtrinsicFeeInstaller {
    let feeAsset: ChainAsset
    let swapState: HydraDx.SwapFeeCurrencyState

    init(
        feeAsset: ChainAsset,
        swapState: HydraDx.SwapFeeCurrencyState
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
        var currentBuiler = builder

        let assetId = try HydraDxTokenConverter.convertToRemote(
            chainAsset: feeAsset,
            codingFactory: coderFactory
        )

        let calls = createFeeCalls(using: assetId)

        if let setCurrencyCall = calls.setCurrencyCall {
            currentBuiler = try currentBuiler.adding(
                call: setCurrencyCall.runtimeCall(),
                at: 0
            )
        }

        if let revertCurrencyCall = calls.revertCurrencyCall {
            currentBuiler = try currentBuiler.adding(
                call: revertCurrencyCall.runtimeCall()
            )
        }

        return currentBuiler
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
