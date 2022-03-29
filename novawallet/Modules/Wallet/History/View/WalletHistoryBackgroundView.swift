import Foundation
import CommonWallet

final class WalletHistoryBackgroundView: TriangularedBlurView {
    let minimizedSideLength: CGFloat = 12.0
    let minBackgroundAlpha: CGFloat = 0.0
    let maxBackgroundAlpha: CGFloat = 0.8
}

extension WalletHistoryBackgroundView: HistoryBackgroundViewProtocol {
    func apply(style _: HistoryViewStyleProtocol) {}

    func applyFullscreen(progress: CGFloat) {
        sideLength = minimizedSideLength * progress

        let alpha = minBackgroundAlpha + (maxBackgroundAlpha - minBackgroundAlpha) * (1.0 - progress)
        let color = R.color.colorBlack()!.withAlphaComponent(alpha)
        overlayView.fillColor = color
    }
}
