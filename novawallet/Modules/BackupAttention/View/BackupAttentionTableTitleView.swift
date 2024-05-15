import UIKit
import SoraUI

final class BackupAttentionTableTitleView: GenericPairValueView<
    UIView,
    GenericPairValueView<UILabel, UILabel>
> {
    var warningIconContainerView: UIView { fView }

    var titleLabel: UILabel { sView.fView }

    var descriptionLabel: UILabel { sView.sView }

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupStyle()
        setupLayout()
        setupImage()
    }
}

// MARK: Private

private extension BackupAttentionTableTitleView {
    func setupStyle() {
        warningIconContainerView.backgroundColor = R.color.colorContainerBackground()
        warningIconContainerView.layer.cornerRadius = 10
        warningIconContainerView.clipsToBounds = true
        warningIconContainerView.layer.borderWidth = 0.5
        warningIconContainerView.layer.borderColor = R.color.colorContainerBorder()?.cgColor

        titleLabel.apply(style: .boldTitle3Warning)
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 0

        descriptionLabel.apply(style: .regularSubhedlineSecondary)
        descriptionLabel.textAlignment = .center
        descriptionLabel.numberOfLines = 0
    }

    func setupLayout() {
        makeVertical()
        sView.makeVertical()

        spacing = 16
        stackView.alignment = .center
        sView.spacing = 8

        warningIconContainerView.snp.makeConstraints { make in
            make.size.equalTo(64)
        }

        setNeedsLayout()
    }

    func setupImage() {
        let image = R.image.iconWarningApp()
        let warningIconImageView = UIImageView(image: image)

        warningIconImageView.contentMode = .scaleAspectFit

        warningIconContainerView.addSubview(warningIconImageView)

        warningIconImageView.snp.makeConstraints { make in
            make.centerX.centerY.equalToSuperview()
            make.size.equalTo(40)
        }

        setNeedsLayout()
    }
}
