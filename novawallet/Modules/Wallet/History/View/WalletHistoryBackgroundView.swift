import Foundation
import CommonWallet

final class WalletHistoryBackgroundView: BlurBackgroundView {
    let minimizedSideLength: CGFloat = 12.0
}

extension WalletHistoryBackgroundView: HistoryBackgroundViewProtocol {
    func apply(style _: HistoryViewStyleProtocol) {}

    func applyFullscreen(progress: CGFloat) {
        sideLength = minimizedSideLength * progress
    }
}
