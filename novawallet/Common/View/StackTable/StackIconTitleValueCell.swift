import Foundation
import UIKit

final class StackIconTitleValueCell: RowView<GenericTitleValueView<IconDetailsView, UILabel>> {
    var titleLabel: UILabel { rowContentView.titleView.detailsLabel }
    var iconView: UIImageView { rowContentView.titleView.imageView }
    var valueLabel: UILabel { rowContentView.valueView }

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
        titleLabel.apply(style: .footnoteSecondary)

        rowContentView.titleView.mode = .iconDetails
        rowContentView.titleView.spacing = 8

        valueLabel.apply(style: .footnotePrimary)
    }
}

extension StackIconTitleValueCell: StackTableViewCellProtocol {}
