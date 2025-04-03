import Foundation
import NovaCrypto
import Operation_iOS

enum WalletRemoteHistorySourceLabel: Int, CaseIterable {
    case transfers
    case rewards
    case extrinsics
    case poolRewards
    case swaps
}

protocol WalletRemoteHistoryItemProtocol {
    var remoteIdentifier: String { get }
    var localIdentifier: String { get }
    var itemBlockNumber: UInt64 { get }
    var itemExtrinsicIndex: UInt16 { get }
    var itemTimestamp: Int64 { get }
    var label: WalletRemoteHistorySourceLabel { get }

    func createTransaction(
        chainAsset: ChainAsset
    ) -> TransactionHistoryItem?
}

struct WalletRemoteHistoryData {
    let historyItems: [WalletRemoteHistoryItemProtocol]
    let context: [String: String]
}

protocol WalletRemoteHistoryFactoryProtocol {
    func isComplete(pagination: Pagination) -> Bool

    func createOperationWrapper(
        for accountId: AccountId,
        pagination: Pagination
    ) -> CompoundOperationWrapper<WalletRemoteHistoryData>
}

enum WalletRemoteHistoryError: Error {
    case fetchParamsCreation
}
