import Foundation
import RobinHood
import BigInt

struct TransactionHistoryItem: Codable {
    enum CodingKeys: String, CodingKey {
        case chainId
        case assetId
        case sender
        case receiver
        case amountInPlank
        case status
        case txHash
        case timestamp
        case fee
        case blockNumber
        case txIndex
        case callPath
        case call
    }

    enum Status: Int16, Codable {
        case pending
        case success
        case failed
    }

    let chainId: String
    let assetId: UInt32
    let sender: String
    let receiver: String?
    let amountInPlank: String?
    let status: Status
    let txHash: String
    let timestamp: Int64
    let fee: String?
    let blockNumber: UInt64?
    let txIndex: UInt16?
    let callPath: CallCodingPath
    let call: Data?
}

extension TransactionHistoryItem: Identifiable {
    var identifier: String { txHash }
}

extension TransactionHistoryItem {
    var walletAssetId: String {
        ChainAssetId(chainId: chainId, assetId: assetId).walletId
    }
}
