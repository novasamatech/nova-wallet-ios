import Foundation
import CommonWallet
import BigInt
import SubstrateSdk

struct EtherscanERC20HistoryResponse: Decodable {
    struct Element: Decodable {
        // swiftlint:disable:next nesting
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
            case status = "txreceipt_status"
        }

        @StringCodable var blockNumber: UInt64
        @OptionStringCodable var transactionIndex: UInt16?
        @StringCodable var timeStamp: Int64
        @HexCodable var hash: Data
        @HexCodable var sender: AccountId
        @HexCodable var recepient: AccountId
        @HexCodable var value: BigUInt
        @HexCodable var gasPrice: BigUInt
        @HexCodable var gasUsed: BigUInt
        @OptionStringCodable var status: Int8?
    }

    let result: [Element]
}

extension EtherscanERC20HistoryResponse.Element: WalletRemoteHistoryItemProtocol {
    var remoteIdentifier: String {
        hash.toHex(includePrefix: true)
    }

    var localIdentifier: String {
        TransactionHistoryItem.createIdentifier(from: remoteIdentifier, source: .evm)
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

    var assetTransactionStatus: AssetTransactionStatus {
        if let status = status {
            return status == 1 ? .commited : .rejected
        } else {
            return .pending
        }
    }

    func createTransactionForAddress(
        _ address: String,
        assetId: String,
        chainAsset: ChainAsset,
        utilityAsset: AssetModel
    ) -> AssetTransactionData {
        let accountId = try? address.toAccountId(using: .ethereum)
        let isSender = sender == accountId

        let peerId = isSender ? recepient : sender
        let peerAddress = (try? peerId.toAddress(using: .ethereum)) ?? peerId.toHex(includePrefix: true)

        let amount = Decimal.fromSubstrateAmount(
            value,
            precision: chainAsset.asset.decimalPrecision
        ) ?? .zero

        let feeInPlank = gasUsed * gasPrice
        let fee = Decimal.fromSubstrateAmount(
            feeInPlank,
            precision: utilityAsset.decimalPrecision
        ) ?? .zero

        let feeModel = AssetTransactionFee(
            identifier: assetId,
            assetId: assetId,
            amount: AmountDecimal(value: fee),
            context: nil
        )

        let type: TransactionType = isSender ? .outgoing : .incoming

        return AssetTransactionData(
            transactionId: hash.toHex(includePrefix: true),
            status: assetTransactionStatus,
            assetId: assetId,
            peerId: peerId.toHex(),
            peerFirstName: nil,
            peerLastName: nil,
            peerName: peerAddress,
            details: "",
            amount: AmountDecimal(value: amount),
            fees: [feeModel],
            timestamp: itemTimestamp,
            type: type.rawValue,
            reason: nil,
            context: nil
        )
    }
}

extension EtherscanERC20HistoryResponse: EtherscanWalletHistoryDecodable {
    var historyItems: [WalletRemoteHistoryItemProtocol] { result }
}
