import Foundation
import IrohaCrypto
import SubstrateSdk
import BigInt

extension TransactionHistoryItem {
    static func createFromSubscriptionResult(
        _ result: TransactionSubscriptionResult,
        accountId: AccountId,
        chain: ChainModel
    ) -> TransactionHistoryItem? {
        do {
            let extrinsic = result.processingResult.extrinsic

            let maybeTxOrigin: AccountId?

            if chain.isEthereumBased {
                let rawOrigin = try extrinsic.signature?.address.map(
                    to: [StringScaleMapper<UInt8>].self
                ).map(\.value)
                maybeTxOrigin = rawOrigin.map { Data($0) }
            } else {
                maybeTxOrigin = try extrinsic.signature?.address.map(to: MultiAddress.self).accountId
            }

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

            return TransactionHistoryItem(
                chainId: chain.chainId,
                sender: sender,
                receiver: receiver,
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
