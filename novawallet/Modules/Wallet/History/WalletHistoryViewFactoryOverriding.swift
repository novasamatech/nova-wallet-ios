import Foundation
import CommonWallet

final class WalletHistoryViewFactoryOverriding: HistoryViewFactoryOverriding {
    func createBackgroundView() -> BaseHistoryBackgroundView? {
        let backgroundView = WalletHistoryBackgroundView()
        let cornerCut: UIRectCorner = [.topLeft, .topRight]
        backgroundView.fullBackgroundView.cornerCut = cornerCut
        backgroundView.minimizedBackgroundView.cornerCut = cornerCut
        return backgroundView
    }
}
