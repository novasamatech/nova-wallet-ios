import Foundation
import BigInt
import SubstrateSdk

struct EtherscanERC20HistoryResponse: Decodable {
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
        }

        @StringCodable var blockNumber: UInt64
        @OptionStringCodable var transactionIndex: UInt16?
        @StringCodable var timeStamp: Int64
        @HexCodable var hash: Data
        @HexCodable var sender: AccountId
        @HexCodable var recepient: AccountId
        @StringCodable var value: BigUInt
        @StringCodable var gasPrice: BigUInt
        @StringCodable var gasUsed: BigUInt
    }

    let result: [Element]
}

extension EtherscanERC20HistoryResponse.Element: WalletRemoteHistoryItemProtocol {
    var remoteIdentifier: String {
        hash.toHex(includePrefix: true)
    }

    var localIdentifier: String {
        TransactionHistoryItem.createIdentifier(from: remoteIdentifier, source: .evmAsset)
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
        .transfers
    }

    func createTransaction(chainAsset: ChainAsset) -> TransactionHistoryItem? {
        let senderAddress = (try? sender.toAddress(using: .ethereum)) ?? sender.toHex(includePrefix: true)
        let receiverAddress = try? recepient.toAddress(using: .ethereum)

        let feeInPlank = gasUsed * gasPrice

        let txHash = hash.toHex(includePrefix: true)
        let source: TransactionHistoryItemSource = .evmAsset
        let remoteIdentifier = TransactionHistoryItem.createIdentifier(from: txHash, source: source)

        return .init(
            identifier: remoteIdentifier,
            source: source,
            chainId: chainAsset.chain.chainId,
            assetId: chainAsset.asset.assetId,
            sender: senderAddress,
            receiver: receiverAddress,
            amountInPlank: String(value),
            status: .success,
            txHash: txHash,
            timestamp: timeStamp,
            fee: String(feeInPlank),
            feeAssetId: nil,
            blockNumber: itemBlockNumber,
            txIndex: itemExtrinsicIndex,
            callPath: .erc20Tranfer,
            call: nil,
            swap: nil
        )
    }
}

extension EtherscanERC20HistoryResponse: EtherscanWalletHistoryDecodable {
    var historyItems: [WalletRemoteHistoryItemProtocol] { result }
}
