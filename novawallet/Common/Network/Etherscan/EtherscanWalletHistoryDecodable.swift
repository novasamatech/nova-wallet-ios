import Foundation

protocol EtherscanWalletHistoryDecodable: Decodable {
    var historyItems: [WalletRemoteHistoryItemProtocol] { get }
}
