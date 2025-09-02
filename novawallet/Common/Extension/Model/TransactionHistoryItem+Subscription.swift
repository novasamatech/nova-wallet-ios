import Foundation
import NovaCrypto
import SubstrateSdk
import BigInt

extension TransactionHistoryItem {
    static func createFromSubscriptionResult(
        _ result: TransactionSubscriptionResult,
        accountId: AccountId,
        chainAsset: ChainAsset,
        runtimeJsonContext: RuntimeJsonContext
    ) -> TransactionHistoryItem? {
        do {
            let chain = chainAsset.chain
            let asset = chainAsset.asset

            let extrinsic = result.processingResult
            let sender = try extrinsic.sender.toAddress(using: chain.chainFormat)

            let address = try accountId.toAddress(using: chain.chainFormat)
            let receiver: AccountAddress? = {
                if sender != address {
                    return address
                } else {
                    if let peerId = extrinsic.peerId {
                        return try? peerId.toAddress(using: chain.chainFormat)
                    } else {
                        return nil
                    }
                }
            }()

            let timestamp = Int64(Date().timeIntervalSince1970)

            let context = runtimeJsonContext.toRawContext()
            let encodedCall = try JSONEncoder.scaleCompatible(with: context).encode(extrinsic.call)

            let amountString = result.processingResult.amount.map { String($0) }

            let maybeFee = result.processingResult.fee.map { String($0) }

            let txHash = (extrinsic.extrinsicHash ?? result.extrinsicHash).toHex(includePrefix: true)
            let source: TransactionHistoryItemSource = .substrate
            let identifier = TransactionHistoryItem.createIdentifier(from: txHash, source: source)

            return TransactionHistoryItem(
                identifier: identifier,
                source: source,
                chainId: chain.chainId,
                assetId: asset.assetId,
                sender: sender,
                receiver: receiver,
                amountInPlank: amountString,
                status: result.processingResult.isSuccess ? .success : .failed,
                txHash: txHash,
                timestamp: timestamp,
                fee: maybeFee,
                feeAssetId: extrinsic.feeAssetId,
                blockNumber: result.blockNumber,
                txIndex: result.txIndex,
                callPath: result.processingResult.callPath,
                call: encodedCall,
                swap: createSwapIfNeeded(from: extrinsic)
            )

        } catch {
            return nil
        }
    }

    private static func createSwapIfNeeded(from subscription: ExtrinsicProcessingResult) -> SwapHistoryData? {
        guard let remoteSwap = subscription.swap else {
            return nil
        }

        return .init(
            amountIn: String(remoteSwap.amountIn),
            assetIdIn: remoteSwap.assetIdIn,
            amountOut: String(remoteSwap.amountOut),
            assetIdOut: remoteSwap.assetIdOut
        )
    }
}
