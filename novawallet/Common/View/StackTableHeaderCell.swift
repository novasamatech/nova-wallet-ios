import UIKit

final class StackTableHeaderCell: RowView<UILabel>, StackTableViewCellProtocol {
    var titleLabel: UILabel { rowContentView }

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
        titleLabel.textColor = R.color.colorWhite()
        titleLabel.font = .regularSubheadline
        titleLabel.textAlignment = .left

        borderView.strokeWidth = 0.0

        isUserInteractionEnabled = false
    }
}
