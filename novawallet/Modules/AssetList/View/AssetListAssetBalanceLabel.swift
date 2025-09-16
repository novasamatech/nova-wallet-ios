import UIKit

final class AssetListAssetBalanceLabel: UILabel {
    private func createAttributedText(from value: String) -> NSAttributedString {
        NSAttributedString.styledAmountString(
            from: value,
            intPartFont: .semiBoldBody,
            fractionFont: .semiBoldSubheadline,
            decimalSeparator: String(String.Separator.dot.rawValue)
        )
    }
}

// MARK: - SecurableViewProtocol

extension AssetListAssetBalanceLabel: SecurableViewProtocol {
    func update(with viewModel: String) {
        attributedText = createAttributedText(from: viewModel)
    }

    func createSecureOverlay() -> UIView? {
        let dotsView = DotsOverlayView()
        dotsView.configuration = .smallBalance

        return dotsView
    }
}
