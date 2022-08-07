import UIKit

extension WalletAccountActionView {
    static func createInfoView() -> WalletAccountActionView {
        let view = WalletAccountActionView()

        view.backgroundView.fillColor = .clear
        view.backgroundView.highlightedFillColor = R.color.colorHighlightedAccent()!
        view.backgroundView.strokeWidth = 1.0
        view.backgroundView.strokeColor = R.color.colorWhite16()!
        view.backgroundView.cornerRadius = 12.0

        view.contentInsets = UIEdgeInsets(top: 7.0, left: 12.0, bottom: 7.0, right: 16.0)
        view.imageIndicator.image = R.image.iconInfo()?.tinted(with: R.color.colorWhite48()!)

        return view
    }
}
