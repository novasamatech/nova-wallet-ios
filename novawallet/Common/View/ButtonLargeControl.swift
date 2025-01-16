import Foundation
import UIKit_iOS
import UIKit

final class ButtonLargeControl: ControlView<RoundedView, IconDetailsGenericView<MultiValueView>> {
    enum Style {
        case primary
        case secondary
    }

    var titleLabel: UILabel { controlContentView.detailsView.valueTop }
    var detailsLabel: UILabel { controlContentView.detailsView.valueBottom }
    var iconView: UIImageView { controlContentView.imageView }

    var style: Style = .primary {
        didSet {
            applyStyle()
        }
    }

    convenience init() {
        self.init(frame: CGRect(origin: .zero, size: CGSize(width: 335, height: 52.0)))
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = .clear
        preferredHeight = 52.0

        configure()
    }

    func bind(title: String, details: String?) {
        controlContentView.detailsView.bind(topValue: title, bottomValue: details)

        setNeedsLayout()
    }

    private func configure() {
        contentInsets = UIEdgeInsets(top: 8.0, left: 12.0, bottom: 8.0, right: 12.0)
        controlContentView.iconWidth = 24.0
        controlContentView.spacing = 12.0

        titleLabel.textColor = R.color.colorTextPrimary()
        titleLabel.font = .semiBoldSubheadline
        titleLabel.textAlignment = .left

        detailsLabel.textColor = R.color.colorTextSecondary()
        detailsLabel.font = .caption1
        detailsLabel.textAlignment = .left

        controlBackgroundView.applyFilledBackgroundStyle()
        controlBackgroundView.cornerRadius = 12.0
        applyStyle()

        changesContentOpacityWhenHighlighted = true
    }

    private func applyStyle() {
        switch style {
        case .primary:
            controlBackgroundView.fillColor = R.color.colorButtonBackgroundPrimary()!
            controlBackgroundView.highlightedFillColor = R.color.colorButtonBackgroundPrimary()!
        case .secondary:
            controlBackgroundView.fillColor = R.color.colorButtonBackgroundSecondary()!
            controlBackgroundView.highlightedFillColor = R.color.colorButtonBackgroundSecondary()!
        }
    }
}
