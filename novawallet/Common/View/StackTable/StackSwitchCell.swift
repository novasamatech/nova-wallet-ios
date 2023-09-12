import UIKit

final class StackSwitchCell: RowView<GenericTitleValueView<MultiValueView, UISwitch>> {
    var titleLabel: UILabel { rowContentView.titleView.valueTop }
    var subtitleLabel: UILabel { rowContentView.titleView.valueBottom }
    var switchControl: UISwitch { rowContentView.valueView }

    convenience init() {
        self.init(frame: CGRect(origin: .zero, size: CGSize(width: 340, height: 44.0)))
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = .clear

        configure()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func configure() {
        hasInteractableContent = true
        roundedBackgroundView.highlightedFillColor = .clear

        titleLabel.apply(style: .footnotePrimary)
        titleLabel.textAlignment = .left

        subtitleLabel.apply(style: .caption1Secondary)
        subtitleLabel.textAlignment = .left

        switchControl.onTintColor = R.color.colorIconAccent()

        rowContentView.titleView.spacing = 2

        rowContentView.titleView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    }
}

extension StackSwitchCell: StackTableViewCellProtocol {}
