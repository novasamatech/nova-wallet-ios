import Foundation
import UIKit
import UIKit_iOS

final class ImageSecureView<View: UIView>: BaseSecureView<View> {
    var overlayConfiguration: RoundedView.Style = .shadowedNft

    private let secureImageProvider: () -> UIImage?

    init(secureImageProvider: @escaping () -> UIImage?) {
        self.secureImageProvider = secureImageProvider

        super.init(frame: .zero)
    }

    override func createSecureOverlay() -> UIView? {
        let roundedView = RoundedView()

        let imageView = UIImageView(image: secureImageProvider())
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = overlayConfiguration.rounding?.radius ?? .zero

        roundedView.addSubview(imageView)

        imageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        roundedView.apply(style: overlayConfiguration)

        return roundedView
    }
}
