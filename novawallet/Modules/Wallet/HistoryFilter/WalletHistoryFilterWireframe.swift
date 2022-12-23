import Foundation
import CommonWallet

final class WalletHistoryFilterWireframe: WalletHistoryFilterWireframeProtocol {
    weak var delegate: TransactionHistoryFilterEditingDelegate?

    init(delegate: TransactionHistoryFilterEditingDelegate?) {
        self.delegate = delegate
    }

    func proceed(from _: WalletHistoryFilterViewProtocol?, applying filter: WalletHistoryFilter) {
        delegate?.historyFilterDidEdit(filter: filter)
    }
}

protocol TransactionHistoryFilterEditingDelegate: AnyObject {
    func historyFilterDidEdit(filter: WalletHistoryFilter)
}
