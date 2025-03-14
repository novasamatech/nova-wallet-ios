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
        rowContentView.fView.spacing = Constants.labelSpacing
        
        rowContentView.sView.snp.makeConstraints { make in
            make.size.equalTo(Constants.iconSize)
        }
    }
    
    func setupStyle() {
        roundedBackgroundView.apply(style: .roundedLightCell)
        copyIcon.image = R.image.iconActionCopy()?.tinted(with: R.color.colorIconAccent()!)
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
        static let iconSize: CGFloat = 32.0
        static let labelSpacing: CGFloat = 8.0
        static let contentInsets: UIEdgeInsets = .init(
            top: 11.0,
            left: 16,
            bottom: 11.0,
            right: 16
        )
    }
}
