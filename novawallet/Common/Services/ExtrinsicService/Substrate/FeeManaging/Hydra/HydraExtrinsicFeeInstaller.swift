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
        let batchType = try resolveBatchType(
            for: builder,
            coderFactory: coderFactory
        )

        let calls = createTransferFeeCalls(using: assetId)

        guard
            let setCurrencyCall = calls.setCurrencyCall,
            let revertCurrencyCall = calls.revertCurrencyCall
        else {
            return builder.with(batchType: batchType)
        }

        return try builder
            .with(batchType: batchType)
            .adding(call: setCurrencyCall.runtimeCall(), at: 0)
            .adding(call: revertCurrencyCall.runtimeCall())
    }
}

// MARK: Private

private extension HydraExtrinsicFeeInstaller {
    func createTransferFeeCalls(using assetId: HydraDx.LocalRemoteAssetId) -> TransferFeeInstallingCalls {
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

        return TransferFeeInstallingCalls(
            setCurrencyCall: setCurrencyCall,
            revertCurrencyCall: revertCurrencyCall
        )
    }

    func resolveBatchType(
        for builder: ExtrinsicBuilderProtocol,
        coderFactory: RuntimeCoderFactoryProtocol
    ) throws -> ExtrinsicBatch {
        let context = coderFactory.createRuntimeJsonContext()

        let containsSetReferralCall = try builder
            .getCalls()
            .map { call in
                try call.map(
                    to: RuntimeCall<NoRuntimeArgs>.self,
                    with: context.toRawContext()
                )
            }
            .contains { $0.moduleName == HydraDx.referralsModule }

        return containsSetReferralCall ? .ignoreFails : .atomic
    }
}
