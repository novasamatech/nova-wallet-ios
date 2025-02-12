import Foundation
import UIKit
import SoraUI

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

    func changeBackground(
        to image: UIImage?,
        progressClosure: () -> CGFloat
    ) {
        let progress = progressClosure()

        print("TRANSITION PROGRESS: \(progress)")

        if progress >= 0, transitionImageView.image == nil {
            transitionImageView.image = image
        }

        transitionImageView.alpha = progress

        if progress == 1 {
            backgroundImageView.image = image
            transitionImageView.image = nil
            transitionImageView.alpha = 0
        }
    }

    func setBackground(_ image: UIImage?) {
        backgroundImageView.image = image
        transitionImageView.image = nil
        transitionImageView.alpha = 0
    }
}
