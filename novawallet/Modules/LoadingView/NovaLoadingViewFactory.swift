import UIKit
import UIKit_iOS

final class NovaLoadingViewFactory: LoadingViewFactoryProtocol {
    static func createLoadingView() -> LoadingView {
        let icon = R.image.iconLoadingIndicator()?.tinted(with: R.color.colorIndicatorShimmering()!)
        let loadingView = LoadingView(
            frame: UIScreen.main.bounds,
            indicatorImage: icon ?? UIImage()
        )
        loadingView.backgroundColor = UIColor.black.withAlphaComponent(0.19)
        loadingView.contentBackgroundColor = .clear
        loadingView.contentSize = CGSize(width: 120.0, height: 120.0)
        loadingView.animationDuration = 1.0
        return loadingView
    }
}
