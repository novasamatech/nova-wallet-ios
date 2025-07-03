import Foundation
import UIKit

final class StackTitleIconDetailsCell: RowView<GenericPairValueView<UILabel, IconDetailsView>> {
    var titleLabel: UILabel { rowContentView.fView }
    var valueLabel: UILabel { rowContentView.sView.detailsLabel }
    var iconView: UIImageView { rowContentView.sView.imageView }

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
        valueLabel.apply(style: .footnoteSecondary)

        rowContentView.makeHorizontal()
        rowContentView.stackView.distribution = .fillProportionally
        rowContentView.sView.mode = .detailsIcon
        rowContentView.sView.detailsLabel.textAlignment = .right
        rowContentView.sView.spacing = 4.0
    }
}

extension StackTitleIconDetailsCell: StackTableViewCellProtocol {}
