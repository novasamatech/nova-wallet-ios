import Foundation
import UIKit

class UnifiedAddressPopupAddressView: RowView<
    GenericPairValueView<
        GenericPairValueView<
            BorderedLabelView,
            UILabel
        >,
        UIImageView
    >
> {
    var formatLabel: BorderedLabelView {
        rowContentView.fView.fView
    }

    var addressLabel: UILabel {
        rowContentView.fView.sView
    }

    var copyIcon: UIImageView {
        rowContentView.sView
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
        setupStyle()
    }
}

// MARK: Private

private extension UnifiedAddressPopupAddressView {
    func setupLayout() {
        contentInsets = Constants.contentInsets

        rowContentView.makeHorizontal()

        rowContentView.fView.stackView.alignment = .leading
        rowContentView.fView.stackView.distribution = .fillProportionally
        rowContentView.fView.spacing = Constants.labelSpacing

        copyIcon.snp.makeConstraints { make in
            make.width.equalTo(Constants.iconWidth)
        }
        addressLabel.snp.makeConstraints { make in
            make.width.equalTo(self).multipliedBy(Constants.addressLabelWidthMultiplier)
        }
        rowContentView.fView.snp.makeConstraints { make in
            make.height.equalTo(Constants.textContainerHeight)
        }
    }

    func setupStyle() {
        addressLabel.lineBreakMode = .byTruncatingMiddle
        formatLabel.contentInsets = Constants.formatLabelContentInset
        roundedBackgroundView.apply(style: .roundedLightCell)

        copyIcon.contentMode = .scaleAspectFit
        copyIcon.image = R.image.iconActionCopy()?
            .tinted(with: R.color.colorIconAccent()!)?
            .withAlignmentRectInsets(Constants.iconImageInsets)
    }
}

// MARK: Internal

extension UnifiedAddressPopupAddressView {
    func apply(style: Style) {
        formatLabel.apply(style: style.chipsStyle)
        addressLabel.apply(style: style.addressStyle)
    }

    func bind(with model: UnifiedAddressPopup.AddressViewModel) {
        addressLabel.text = model.addressText
        formatLabel.titleLabel.text = model.formatText
    }
}

// MARK: Constants

private extension UnifiedAddressPopupAddressView {
    enum Constants {
        static let iconWidth: CGFloat = 32.0
        static let textContainerHeight: CGFloat = 42.0
        static let addressLabelWidthMultiplier: CGFloat = 0.612

        static let labelSpacing: CGFloat = 8.0

        static let formatLabelContentInset = UIEdgeInsets(
            top: 2.0,
            left: 6.0,
            bottom: 2.0,
            right: 6.0
        )
        static let contentInsets = UIEdgeInsets(
            top: 11.0,
            left: 16,
            bottom: 11.0,
            right: 16
        )
        static let iconImageInsets = UIEdgeInsets(inset: -9.0)
    }
}
