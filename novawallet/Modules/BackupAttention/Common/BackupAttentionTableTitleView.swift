import UIKit
import SoraUI

final class BackupAttentionTableTitleView: GenericPairValueView<
    UIImageView,
    GenericPairValueView<UILabel, UILabel>
> {
    var warningIconImageView: UIImageView { fView }

    var titleLabel: UILabel { sView.fView }

    var descriptionLabel: UILabel { sView.sView }

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupStyle()
        setupLayout()
        setupResources()
    }
}

// MARK: Private

private extension BackupAttentionTableTitleView {
    func setupStyle() {
        warningIconImageView.contentMode = .scaleAspectFit

        titleLabel.font = .h2Title
        titleLabel.textColor = R.color.colorTextWarning()
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 0

        descriptionLabel.font = .p1Paragraph
        descriptionLabel.textColor = R.color.colorTextSecondary()
        descriptionLabel.textAlignment = .center
        descriptionLabel.numberOfLines = 0
    }

    func setupLayout() {
        makeVertical()
        sView.makeVertical()

        spacing = 16
        sView.spacing = 8

        warningIconImageView.snp.makeConstraints { make in
            make.size.equalTo(64)
        }
    }

    func setupResources() {
        warningIconImageView.image = R.image.iconWarningApp()
        titleLabel.text = "Do not share your passphrase!"
        descriptionLabel.text = "Please read the following carefully before viewing your backup"
    }
}
