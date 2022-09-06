import UIKit

final class LedgerAccountStackCell: RowView<GenericTitleValueView<IconDetailsGenericView<MultiValueView>, UIImageView>> {
    var addressLabel: UILabel { rowContentView.titleView.detailsView.valueTop }
    var amountLabel: UILabel { rowContentView.titleView.detailsView.valueBottom }
    var iconView: UIImageView { rowContentView.titleView.imageView }
    var indicatorView: UIImageView { rowContentView.valueView }

    convenience init() {
        self.init(frame: CGRect(origin: .zero, size: CGSize(width: 340, height: 48.0)))
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = .clear

        preferredHeight = 48.0
        contentInsets = UIEdgeInsets(top: 5.0, left: 16.0, bottom: 5.0, right: 16.0)

        configure()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func configure() {
        borderView.borderType = []

        addressLabel.textColor = R.color.colorWhite()
        addressLabel.font = .regularSubheadline
        addressLabel.lineBreakMode = .byTruncatingMiddle
        addressLabel.textAlignment = .left

        amountLabel.textColor = R.color.colorTransparentText()
        amountLabel.font = .regularFootnote
        amountLabel.textAlignment = .left

        rowContentView.titleView.mode = .iconDetails
        rowContentView.titleView.spacing = 12.0
        rowContentView.titleView.iconWidth = 32.0

        indicatorView.image = R.image.iconSmallArrow()?.tinted(with: R.color.colorWhite48()!)
    }

    func bind(viewModel: LedgerAccountViewModel) {
        let size = rowContentView.titleView.iconWidth
        viewModel.icon?.loadImage(on: iconView, targetSize: CGSize(width: size, height: size), animated: true)

        addressLabel.text = viewModel.address
        amountLabel.text = viewModel.amount
    }
}
