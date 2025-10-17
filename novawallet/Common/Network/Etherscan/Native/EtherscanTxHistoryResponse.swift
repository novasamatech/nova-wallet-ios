import Foundation
import SubstrateSdk
import BigInt

struct EtherscanTxHistoryResponse: Decodable {
    struct Element: Decodable {
        enum CodingKeys: String, CodingKey {
            case blockNumber
            case transactionIndex
            case timeStamp
            case hash
            case sender = "from"
            case recepient = "to"
            case value
            case gasPrice
            case gasUsed
            case input
            case status = "txreceipt_status"
            case functionName
        }

        @StringCodable var blockNumber: UInt64
        @OptionStringCodable var transactionIndex: UInt16?
        @StringCodable var timeStamp: Int64
        @HexCodable var hash: Data
        @HexCodable var sender: AccountId
        @OptionHexCodable var recepient: AccountId?
        @StringCodable var value: BigUInt
        @StringCodable var gasPrice: BigUInt
        @StringCodable var gasUsed: BigUInt
        @OptionHexCodable var input: Data?
        @OptionStringCodable var status: Int8?
        let functionName: String?

        var isTransfer: Bool {
            (input ?? Data()).isEmpty
        }
    }

    let result: [Element]
}

extension EtherscanTxHistoryResponse.Element: WalletRemoteHistoryItemProtocol {
    var remoteIdentifier: String {
        hash.toHex(includePrefix: true)
    }

    var localIdentifier: String {
        TransactionHistoryItem.createIdentifier(from: remoteIdentifier, source: .evmNative)
    }

    var itemBlockNumber: UInt64 {
        blockNumber
    }

    var itemExtrinsicIndex: UInt16 {
        transactionIndex ?? 0
    }

    var itemTimestamp: Int64 {
        timeStamp
    }

    var label: WalletRemoteHistorySourceLabel {
        isTransfer ? .transfers : .extrinsics
    }

    var transactionStatus: TransactionHistoryItem.Status {
        if let status = status {
            return status == 1 ? .success : .failed
        } else {
            return .pending
        }
    }

    func createTransaction(chainAsset: ChainAsset) -> TransactionHistoryItem? {
        let senderAddress = (try? sender.toAddress(using: .ethereum)) ?? sender.toHex(includePrefix: true)
        let receiverAddress = try? recepient?.toAddress(using: .ethereum)

        let feeInPlank = gasUsed * gasPrice

        let callData = functionName?.data(using: .utf8)

        let txHash = hash.toHex(includePrefix: true)
        let source: TransactionHistoryItemSource = .evmNative
        let identifier = TransactionHistoryItem.createIdentifier(from: txHash, source: source)

        return .init(
            identifier: identifier,
            source: source,
            chainId: chainAsset.chain.chainId,
            assetId: chainAsset.asset.assetId,
            sender: senderAddress,
            receiver: receiverAddress,
            amountInPlank: String(value),
            status: transactionStatus,
            txHash: txHash,
            timestamp: timeStamp,
            fee: String(feeInPlank),
            feeAssetId: nil,
            blockNumber: itemBlockNumber,
            txIndex: itemExtrinsicIndex,
            callPath: isTransfer ? .evmNativeTransfer : .evmNativeTransaction,
            call: callData,
            swap: nil
        )
    }
}

extension EtherscanTxHistoryResponse: EtherscanWalletHistoryDecodable {
    var historyItems: [WalletRemoteHistoryItemProtocol] { result }
}
