import UIKit

final class AssetListAssetValueLabel: UILabel, SecurableViewProtocol {
    func update(with viewModel: String) {
        text = viewModel
    }

    func createSecureOverlay() -> UIView? {
        let dotsView = DotsOverlayView()
        dotsView.configuration = .smallBalance

        return dotsView
    }
}
