import UIKit

final class TitleHorizontalMultiValueView: GenericTitleValueView<UILabel, UIStackView> {
    let detailsTitleLabel: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorTextSecondary()
        label.font = .regularFootnote
        return label
    }()

    let detailsValueLabel: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorTextPrimary()
        label.font = .regularFootnote
        return label
    }()

    convenience init() {
        self.init(frame: .zero)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        configureStyle()
    }

    private func configureStyle() {
        titleView.textColor = R.color.colorTextSecondary()
        titleView.font = .regularFootnote

        valueView.spacing = 4.0
        valueView.addArrangedSubview(detailsTitleLabel)
        valueView.addArrangedSubview(detailsValueLabel)

        detailsTitleLabel.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
    }
}
