import Foundation
import UIKit

class BannerBackgroundView: UIView {
    private let fImageView: UIImageView = .create { view in
        view.contentMode = .scaleAspectFill
    }

    private let sImageView: UIImageView = .create { view in
        view.contentMode = .scaleAspectFill
    }

    private var currentTransitingImage: UIImage?

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()

        sImageView.isHidden = true
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        [
            fImageView,
            sImageView
        ].forEach { view in
            addSubview(view)

            view.snp.makeConstraints { make in
                make.edges.equalToSuperview()
            }
        }
    }

    func changeBackground(
        to image: UIImage?,
        progressClosure: () -> CGFloat
    ) {
        let progress = progressClosure()

        if progress > 0, progress < 1 {
            if let currentTransitingImage {
                sImageView.image = currentTransitingImage
            } else {
                currentTransitingImage = image
                sImageView.image = image
            }

            sImageView.alpha = min(progress, 1)
            sImageView.isHidden = false
        } else {
            fImageView.image = currentTransitingImage
            sImageView.alpha = 0.0
            sImageView.isHidden = true
            sImageView.image = nil

            currentTransitingImage = nil
        }
    }

    func setBackground(_ image: UIImage?) {
        fImageView.image = image
    }
}
