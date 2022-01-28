import Foundation
import CommonWallet
import IrohaCrypto
import RobinHood

enum WalletRemoteHistorySourceLabel: Int, CaseIterable {
    case transfers
    case rewards
    case extrinsics
}

protocol WalletRemoteHistoryItemProtocol {
    var remoteIdentifier: String { get }
    var localIdentifier: String { get }
    var itemBlockNumber: UInt64 { get }
    var itemExtrinsicIndex: UInt16 { get }
    var itemTimestamp: Int64 { get }
    var label: WalletRemoteHistorySourceLabel { get }

    func createTransactionForAddress(
        _ address: String,
        assetId: String,
        chainAssetInfo: ChainAssetDisplayInfo
    ) -> AssetTransactionData
}

struct WalletRemoteHistoryData {
    let historyItems: [WalletRemoteHistoryItemProtocol]
    let context: [String: String]
}

protocol WalletRemoteHistoryFactoryProtocol {
    func isComplete(pagination: Pagination) -> Bool

    func createOperationWrapper(for address: String, pagination: Pagination)
        -> CompoundOperationWrapper<WalletRemoteHistoryData>
}
