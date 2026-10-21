import Foundation
import UIKit
import UIKit_iOS

class BannerBackgroundView: UIView {
    private let backgroundImageView: UIImageView = .create { view in
        view.contentMode = .scaleAspectFill
    }

    private let transitionImageView: UIImageView = .create { view in
        view.contentMode = .scaleAspectFill
        view.alpha = 0
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        [
            backgroundImageView,
            transitionImageView
        ].forEach { view in
            addSubview(view)

            view.snp.makeConstraints { make in
                make.edges.equalToSuperview()
            }
        }
    }

    func setBackground(
        _ image: UIImage?,
        blendingTo nextImage: UIImage?,
        progress: CGFloat
    ) {
        backgroundImageView.image = image
        transitionImageView.image = nextImage
        transitionImageView.alpha = progress
    }
}
