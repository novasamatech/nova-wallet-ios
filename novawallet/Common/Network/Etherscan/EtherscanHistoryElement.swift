import Foundation
import CommonWallet
import BigInt

struct EtherscanHistoryElement: Decodable {
    let blockNumber: String
    let transactionIndex: String?
    let timeStamp: String
    let hash: String
    let from: String
    // swiftlint:disable:next identifier_name
    let to: String
    let value: String
    let gasPrice: String
    let gasUsed: String
}

struct EtherscanResponse: Decodable {
    let result: [EtherscanHistoryElement]
}

extension EtherscanHistoryElement: WalletRemoteHistoryItemProtocol {
    var remoteIdentifier: String {
        hash
    }

    var localIdentifier: String {
        hash
    }

    var itemBlockNumber: UInt64 {
        UInt64(blockNumber) ?? 0
    }

    var itemExtrinsicIndex: UInt16 {
        transactionIndex.flatMap { UInt16($0) } ?? 0
    }

    var itemTimestamp: Int64 {
        Int64(timeStamp) ?? 0
    }

    var label: WalletRemoteHistorySourceLabel {
        .transfers
    }

    func createTransactionForAddress(
        _ address: String,
        assetId: String,
        chainAsset: ChainAsset,
        utilityAsset: AssetModel
    ) -> AssetTransactionData {
        let isSender = address.caseInsensitiveCompare(from) == .orderedSame
        let senderAccountId = try? from.toAccountId(using: chainAsset.chain.chainFormat)
        let receiverAccountId = try? to.toAccountId(using: chainAsset.chain.chainFormat)

        let peerId = isSender ? receiverAccountId : senderAccountId
        let peerAddress = isSender ? to : from

        let amountInPlank = BigUInt(value) ?? 0
        let amount = Decimal.fromSubstrateAmount(
            amountInPlank,
            precision: chainAsset.asset.decimalPrecision
        ) ?? .zero

        let gasValue = BigUInt(gasUsed) ?? 0
        let gasPriceValue = BigUInt(gasPrice) ?? 0
        let feeInPlank = gasValue * gasPriceValue
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
            transactionId: hash,
            status: .commited,
            assetId: assetId,
            peerId: peerId?.toHex(includePrefix: true) ?? peerAddress,
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
