import UIKit
import SoraUI

final class VoteRowIndicatorView: RoundedView {
    var preferredSize = CGSize(width: 4.0, height: 16.0) {
        didSet {
            invalidateIntrinsicContentSize()
        }
    }

    override var intrinsicContentSize: CGSize {
        preferredSize
    }
}

final class VoteRowView: RowView<
    GenericTitleValueView<GenericPairValueView<VoteRowIndicatorView, UILabel>, IconDetailsView>
> {
    var titleLabel: UILabel { rowContentView.titleView.sView }

    var detailsLabel: UILabel { rowContentView.valueView.detailsLabel }

    var indicatorView: RoundedView { rowContentView.titleView.fView }

    var trailingImageView: UIImageView { rowContentView.valueView.imageView }

    override init(frame: CGRect) {
        super.init(frame: frame)

        configureStyle()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func configureStyle() {
        preferredHeight = 44.0
        roundedBackgroundView.highlightedFillColor = R.color.colorCellBackgroundPressed()!
        borderView.borderType = .none

        rowContentView.titleView.setHorizontalAndSpacing(16.0)
        rowContentView.valueView.spacing = 8.0
        rowContentView.valueView.mode = .detailsIcon

        indicatorView.cornerRadius = 2.0

        rowContentView.valueView.iconWidth = 16.0

        titleLabel.apply(style: .rowTitle)
        detailsLabel.apply(style: .rowTitle)
    }
}

extension VoteRowView {
    struct Style {
        var color: UIColor
        var accessoryImage: UIImage
    }

    func apply(style: Style) {
        indicatorView.fillColor = style.color
        trailingImageView.image = style.accessoryImage

        setNeedsLayout()
    }
}

extension VoteRowView {
    struct Model {
        let title: String
        let votes: String
    }

    func bind(viewModel: Model) {
        titleLabel.text = viewModel.title
        detailsLabel.text = viewModel.votes
    }

    func bindOrHide(viewModel: Model?) {
        if let viewModel = viewModel {
            isHidden = false
            bind(viewModel: viewModel)
        } else {
            isHidden = true
        }
    }
}

extension UILabel.Style {
    static let rowTitle = UILabel.Style(
        textColor: R.color.colorTextPrimary(),
        font: .regularFootnote
    )
}
