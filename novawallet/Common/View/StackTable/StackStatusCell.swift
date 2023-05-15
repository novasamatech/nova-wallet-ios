import UIKit

final class StackStatusCell: RowView<GenericTitleValueView<UILabel, GlowingStatusView>> {
    var titleLabel: UILabel { rowContentView.titleView }
    var statusView: GlowingStatusView { rowContentView.valueView }

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
        isUserInteractionEnabled = false

        titleLabel.textColor = R.color.colorTextSecondary()
        titleLabel.font = .regularFootnote

        statusView.apply(style: .active)
    }
}

extension StackStatusCell: StackTableViewCellProtocol {}
