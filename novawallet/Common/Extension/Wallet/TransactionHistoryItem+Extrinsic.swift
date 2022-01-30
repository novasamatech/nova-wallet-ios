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
            let extrinsic = result.processingResult.extrinsic
            let chain = chainAsset.chain
            let asset = chainAsset.asset

            let maybeTxOrigin: AccountId? = try extrinsic.signature?.address.map(
                to: MultiAddress.self,
                with: runtimeJsonContext.toRawContext()
            ).accountId

            guard let txOrigin = maybeTxOrigin else {
                return nil
            }

            let sender = try txOrigin.toAddress(using: chain.chainFormat)

            let address = try accountId.toAddress(using: chain.chainFormat)
            let receiver: AccountAddress? = {
                if sender != address {
                    return address
                } else {
                    if let peerId = result.processingResult.peerId {
                        return try? peerId.toAddress(using: chain.chainFormat)
                    } else {
                        return nil
                    }
                }
            }()

            let timestamp = Int64(Date().timeIntervalSince1970)

            let encodedCall = try JSONEncoder.scaleCompatible().encode(extrinsic.call)

            let amountString = result.processingResult.amount.map { String($0) }

            return TransactionHistoryItem(
                chainId: chain.chainId,
                assetId: asset.assetId,
                sender: sender,
                receiver: receiver,
                amountInPlank: amountString,
                status: result.processingResult.isSuccess ? .success : .failed,
                txHash: result.extrinsicHash.toHex(includePrefix: true),
                timestamp: timestamp,
                fee: String(result.processingResult.fee ?? 0),
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
