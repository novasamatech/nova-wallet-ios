import Foundation
import SubstrateSdk

extension AssetHubCommissionHistoryParser {
    struct CollectionCall {
        let beneficiary: AccountId
        let amount: Balance
        let assetId: JSON?
    }

    func validate(
        collection: CollectionCall,
        call: AnyRuntimeCall,
        storageInfo: AssetStorageInfo
    ) throws {
        switch storageInfo {
        case .native:
            guard call.path == .transferKeepAlive else {
                throw AssetHubCommissionHistoryError.unrecognizedCommissionedCall
            }
        case let .statemine(info):
            guard
                call.path == PalletAssets.assetsTransferKeepAlive(for: info.palletName),
                collection.assetId == info.assetId else {
                throw AssetHubCommissionHistoryError.unrecognizedCommissionedCall
            }
        case .orml, .ormlHydrationEvm, .erc20, .evmNative, .equilibrium:
            throw AssetHubCommissionHistoryError.unsupportedOutputAsset
        }
    }

    func decodeCollectionCall(
        _ call: AnyRuntimeCall,
        context: RuntimeJsonContext
    ) throws -> CollectionCall {
        if call.path == .transferKeepAlive {
            let transfer: TransferCall = try ExtrinsicExtraction.getCallArgs(from: call.args, context: context)

            guard let beneficiary = transfer.dest.accountId else {
                throw AssetHubCommissionHistoryError.unrecognizedCommissionedCall
            }

            return CollectionCall(beneficiary: beneficiary, amount: transfer.value, assetId: nil)
        } else {
            let transfer: PalletAssets.TransferCall = try ExtrinsicExtraction.getCallArgs(
                from: call.args,
                context: context
            )

            guard let beneficiary = transfer.target.accountId else {
                throw AssetHubCommissionHistoryError.unrecognizedCommissionedCall
            }

            return CollectionCall(beneficiary: beneficiary, amount: transfer.amount, assetId: transfer.assetId)
        }
    }

    struct DecodedSwapCall {
        let call: AssetHubExchangeSwapParams.Swap
        let path: [AssetConversionPallet.AssetId]
        let receiver: AccountId
        let amountIn: Balance
        let amountOut: Balance
    }

    func decodeSwapCall(
        _ call: AnyRuntimeCall,
        context: RuntimeJsonContext
    ) throws -> DecodedSwapCall? {
        switch call.path {
        case AssetConversionPallet.swapExactTokenForTokensPath:
            let swap: AssetConversionPallet.SwapExactTokensForTokensCall = try ExtrinsicExtraction.getCallArgs(
                from: call.args,
                context: context
            )

            return DecodedSwapCall(
                call: .exactIn(swap),
                path: swap.path,
                receiver: swap.sendTo,
                amountIn: swap.amountIn,
                amountOut: swap.amountOutMin
            )
        case AssetConversionPallet.swapTokenForExactTokens:
            let swap: AssetConversionPallet.SwapTokensForExactTokensCall = try ExtrinsicExtraction.getCallArgs(
                from: call.args,
                context: context
            )

            return DecodedSwapCall(
                call: .exactOut(swap),
                path: swap.path,
                receiver: swap.sendTo,
                amountIn: swap.amountInMax,
                amountOut: swap.amountOut
            )
        default:
            return nil
        }
    }
}
