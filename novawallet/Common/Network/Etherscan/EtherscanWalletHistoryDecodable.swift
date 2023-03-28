import Foundation
import CommonWallet

protocol EtherscanWalletHistoryDecodable: Decodable {
    var historyItems: [WalletRemoteHistoryItemProtocol] { get }
}
