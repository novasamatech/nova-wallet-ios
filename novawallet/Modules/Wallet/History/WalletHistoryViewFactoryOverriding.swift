import Foundation
import CommonWallet

final class WalletHistoryViewFactoryOverriding: HistoryViewFactoryOverriding {
    func createBackgroundView() -> BaseHistoryBackgroundView? {
        let backgroundView = WalletHistoryBackgroundView()
        backgroundView.cornerCut = [.topLeft, .topRight]
        backgroundView.blurStyle = .dark
        return backgroundView
    }
}
