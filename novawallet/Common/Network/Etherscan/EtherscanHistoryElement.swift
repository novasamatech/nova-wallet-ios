import Foundation
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
        TransactionHistoryItem.createIdentifier(from: hash, source: .evm)
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

    func createTransaction(chainAsset: ChainAsset) -> TransactionHistoryItem? {
        let gasValue = BigUInt(gasUsed) ?? 0
        let gasPriceValue = BigUInt(gasPrice) ?? 0
        let feeInPlank = gasValue * gasPriceValue

        return .init(
            source: .evm,
            chainId: chainAsset.chainAssetId.chainId,
            assetId: chainAsset.chainAssetId.assetId,
            sender: from,
            receiver: to,
            amountInPlank: value,
            status: .success,
            txHash: hash,
            timestamp: itemTimestamp,
            fee: String(feeInPlank),
            blockNumber: itemBlockNumber,
            txIndex: nil,
            callPath: CallCodingPath.erc20Tranfer,
            call: nil
        )
    }
}
