import Foundation
import SubstrateSdk

struct SubqueryPageInfo: Decodable {
    let startCursor: String?
    let endCursor: String?
}

struct SubqueryTransfer: Codable {
    enum CodingKeys: String, CodingKey {
        case amount
        case receiver = "to"
        case sender = "from"
        case fee
        case eventIdx
        case success
    }

    let amount: String
    let receiver: String
    let sender: String
    let fee: String
    let eventIdx: Int
    let success: Bool
}

struct SubqueryRewardOrSlash: Codable {
    let eventIdx: Int
    let amount: String
    let isReward: Bool
    let era: Int?
    let stash: String?
    let validator: String?
}

struct SubqueryExtrinsic: Decodable {
    let hash: String
    let module: String
    let call: String
    let fee: String
    let success: Bool
}

struct SubqueryPoolRewardOrSlash: Codable {
    let eventIdx: Int
    let amount: String
    let isReward: Bool
    let poolId: Int
}

struct SubquerySwap: Codable {
    let assetIdIn: String?
    let amountIn: String
    let assetIdOut: String?
    let amountOut: String
    let sender: String
    let receiver: String
    let fee: String
    let eventIdx: Int
}

struct SubqueryHistoryElement: Decodable {
    enum CodingKeys: String, CodingKey {
        case identifier = "id"
        case blockNumber
        case extrinsicIdx
        case extrinsicHash
        case timestamp
        case address
        case reward
        case extrinsic
        case transfer
        case assetTransfer
        case poolReward
        case swap
    }

    let identifier: String
    let blockNumber: UInt64
    let extrinsicIdx: UInt16?
    let extrinsicHash: String?
    let timestamp: String
    let address: String
    let reward: SubqueryRewardOrSlash?
    let extrinsic: SubqueryExtrinsic?
    let transfer: SubqueryTransfer?
    let assetTransfer: SubqueryTransfer?
    let poolReward: SubqueryPoolRewardOrSlash?
    let swap: SubquerySwap?
}

struct SubqueryHistoryData: Decodable {
    struct HistoryElements: Decodable {
        let pageInfo: SubqueryPageInfo
        let nodes: [SubqueryHistoryElement]
    }

    let historyElements: HistoryElements
}

struct SubqueryRewardOrSlashData: Decodable {
    struct HistoryElements: Decodable {
        let nodes: [SubqueryHistoryElement]
    }

    let historyElements: HistoryElements
}
