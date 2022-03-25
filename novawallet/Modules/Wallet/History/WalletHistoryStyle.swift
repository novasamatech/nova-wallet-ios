import Foundation
import CommonWallet

extension HistoryViewStyle {
    static var fearless: HistoryViewStyleProtocol {
        let borderStyle = WalletStrokeStyle(color: .clear, lineWidth: 0.0)
        let cornerRadius: CGFloat = 12.0
        let titleStyle = WalletTextStyle(
            font: .semiBoldBody,
            color: .white
        )

        return HistoryViewStyle(
            fillColor: UIColor.black.withAlphaComponent(0.7),
            borderStyle: borderStyle,
            cornerRadius: cornerRadius,
            titleStyle: titleStyle,
            filterIcon: R.image.iconFilter(),
            closeIcon: R.image.iconClose(),
            panIndicatorStyle: UIColor.white,
            shouldInsertFullscreenShadow: false,
            shadow: nil,
            separatorStyle: nil,
            pageLoadingIndicatorColor: R.color.colorTransparentText()
        )
    }
}
