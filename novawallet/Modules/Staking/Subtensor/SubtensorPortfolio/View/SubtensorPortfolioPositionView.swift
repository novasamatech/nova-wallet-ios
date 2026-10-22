import UIKit

final class SubtensorPortfolioPositionView: UIControl {
    let iconView: AssetIconView = .create { view in
        view.backgroundView.cornerRadius = Constants.iconSize.height / 2
        view.imageView.layer.cornerRadius = Constants.iconSize.height / 2
        view.imageView.clipsToBounds = true
    }

    let titleLabel: UILabel = .create { label in
        label.apply(style: .semiboldBodyPrimary)
    }

    let subtitleLabel: UILabel = .create { label in
        label.apply(style: .footnoteSecondary)
    }

    let valueLabel: UILabel = .create { label in
        label.textAlignment = .right
    }

    let detailLabel: UILabel = .create { label in
        label.apply(style: .footnoteSecondary)
        label.textAlignment = .right
    }

    let chevronView: UIImageView = .create { view in
        view.image = R.image.iconSmallArrow()?.tinted(with: R.color.colorIconSecondary()!)
        view.contentMode = .scaleAspectFit
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = R.color.colorBlockBackground()
        layer.cornerRadius = 12

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(viewModel: SubtensorPortfolioRowViewModel) {
        iconView.bind(viewModel: viewModel.icon, size: Constants.iconSize)

        titleLabel.text = viewModel.title
        subtitleLabel.text = viewModel.subtitle
        subtitleLabel.isHidden = viewModel.subtitle == nil
        bind(value: viewModel.value, symbol: viewModel.symbol)

        switch viewModel.detail {
        case .none:
            detailLabel.text = nil
            detailLabel.isHidden = true
        case let .fiat(text):
            detailLabel.text = text
            detailLabel.textColor = R.color.colorTextSecondary()
            detailLabel.isHidden = false
        case let .change(change):
            detailLabel.text = change.text
            detailLabel.textColor = change.isRising ? R.color.colorTextPositive() : R.color.colorTextNegative()
            detailLabel.isHidden = false
        }
    }
}

private extension SubtensorPortfolioPositionView {
    enum Constants {
        static let iconSize = CGSize(width: 40, height: 40)
        static let chevronSize: CGFloat = 20
        static let minHeight: CGFloat = 64
        static let titleHeight: CGFloat = 22
        static let detailHeight: CGFloat = 18
    }

    func bind(value: String, symbol: String) {
        let text = NSMutableAttributedString(string: value, attributes: [
            .font: UIFont.semiBoldBody,
            .foregroundColor: R.color.colorTextPrimary()!
        ])

        if let range = value.range(of: symbol, options: .backwards) {
            text.addAttributes(
                [.font: UIFont.semiBoldSubheadline, .foregroundColor: R.color.colorTextSecondary()!],
                range: NSRange(range, in: value)
            )
        }

        valueLabel.attributedText = text
    }

    func setupLayout() {
        let titleView = UIView.vStack(alignment: .leading, [titleLabel, subtitleLabel])
        let valueView = UIView.vStack(alignment: .trailing, [valueLabel, detailLabel])

        let contentView = UIView.hStack(
            alignment: .center,
            spacing: 12,
            [iconView, titleView, UIView(), valueView, chevronView]
        )

        contentView.setCustomSpacing(20, after: valueView)
        contentView.isUserInteractionEnabled = false

        addSubview(contentView)
        contentView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(12)
            make.top.bottom.equalToSuperview().inset(12)
        }

        snp.makeConstraints { make in
            make.height.greaterThanOrEqualTo(Constants.minHeight)
        }

        iconView.snp.makeConstraints { make in
            make.size.equalTo(Constants.iconSize)
        }

        chevronView.snp.makeConstraints { make in
            make.size.equalTo(Constants.chevronSize)
        }

        [titleLabel, valueLabel].forEach { label in
            label.snp.makeConstraints { make in
                make.height.equalTo(Constants.titleHeight)
            }
        }

        [subtitleLabel, detailLabel].forEach { label in
            label.snp.makeConstraints { make in
                make.height.equalTo(Constants.detailHeight)
            }
        }

        titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        valueLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        detailLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
    }
}
