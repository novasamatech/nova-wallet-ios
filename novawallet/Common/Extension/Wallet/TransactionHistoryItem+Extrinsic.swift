import Foundation
import IrohaCrypto
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

            let txHash = extrinsic.extrinsicHash ?? result.extrinsicHash
            return TransactionHistoryItem(
                chainId: chain.chainId,
                assetId: asset.assetId,
                sender: sender,
                receiver: receiver,
                amountInPlank: amountString,
                status: result.processingResult.isSuccess ? .success : .failed,
                txHash: txHash.toHex(includePrefix: true),
                timestamp: timestamp,
                fee: maybeFee,
                blockNumber: result.blockNumber,
                txIndex: result.txIndex,
                callPath: result.processingResult.callPath,
                call: encodedCall
            )

        } catch {
            return nil
        }
    }
}
