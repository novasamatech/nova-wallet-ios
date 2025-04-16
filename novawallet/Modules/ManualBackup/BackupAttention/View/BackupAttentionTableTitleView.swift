import UIKit
import UIKit_iOS

final class BackupAttentionTableTitleView: GenericPairValueView<
    DAppIconView,
    GenericPairValueView<UILabel, UILabel>
> {
    var warningIconView: DAppIconView { fView }

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
        warningIconView.backgroundView.cornerRadius = UIConstants.warningIconCornerRadius
        warningIconView.backgroundView.strokeWidth = UIConstants.warningIconStrokeWidth
        warningIconView.backgroundView.strokeColor = R.color.colorContainerBorder()!

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

        warningIconView.contentInsets = UIConstants.warningIconContentInsets
        warningIconView.snp.makeConstraints { make in
            make.size.equalTo(64)
        }

        setNeedsLayout()
    }

    func setupImage() {
        warningIconView.imageView.image = R.image.iconWarningApp()
    }
}

// MARK: UIConstants

private extension UIConstants {
    static let warningIconStrokeWidth: CGFloat = 0.5
    static let warningIconCornerRadius: CGFloat = 10
    static let warningIconContentInsets: UIEdgeInsets = .init(top: 12, left: 12, bottom: 12, right: 12)
}
