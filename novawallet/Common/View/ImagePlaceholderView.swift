import UIKit
import SoraUI

final class ImagePlaceholderView: RoundedView {
    let iconView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .center
        imageView.image = R.image.iconImagePlaceholder()
        return imageView
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)

        configureStyle()
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func configureStyle() {
        applyFilledBackgroundStyle()

        fillColor = R.color.colorWhite16()!
        cornerRadius = 8.0
    }

    private func setupLayout() {
        addSubview(iconView)
        iconView.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }
    }
}
