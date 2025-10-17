import UIKit

final class GenericLedgerNotFoundAddressContentView: GenericTitleValueView<UILabel, IconDetailsView> {
    var titleLabel: UILabel { titleView }
    var detailsLabel: UILabel { valueView.detailsLabel }
    var indicatorView: UIImageView { valueView.imageView }

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
        detailsLabel.apply(style: .footnoteSecondary)

        valueView.mode = .iconDetails
        valueView.iconWidth = 20
        valueView.spacing = 8

        indicatorView.image = R.image.iconWarning()
    }

    func bind(title: String, locale: Locale) {
        titleLabel.text = title

        detailsLabel.text = R.string(preferredLanguages: locale.rLanguages).localizable.accountNotFoundCaption()
    }
}
