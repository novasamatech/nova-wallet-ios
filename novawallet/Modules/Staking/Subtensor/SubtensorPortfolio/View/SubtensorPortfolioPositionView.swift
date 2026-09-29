import UIKit

final class SubtensorPortfolioPositionView: UIControl {
    let iconView: UIImageView = .create { view in
        view.contentMode = .scaleAspectFit
    }

    let titleLabel: UILabel = .create { label in
        label.apply(style: .regularBodyPrimary)
    }

    let subtitleLabel: UILabel = .create { label in
        label.apply(style: .footnoteSecondary)
    }

    let valueLabel: UILabel = .create { label in
        label.apply(style: .semiboldBodyPrimary)
        label.textAlignment = .right
    }

    let detailLabel: UILabel = .create { label in
        label.apply(style: .footnoteSecondary)
        label.textAlignment = .right
    }

    let chevronView: UIImageView = .create { view in
        view.image = R.image.iconChevronRight()?.tinted(with: R.color.colorIconSecondary()!)
        view.contentMode = .scaleAspectFit
    }

    private var imageViewModel: ImageViewModelProtocol?

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
        imageViewModel?.cancel(on: iconView)
        imageViewModel = viewModel.icon
        viewModel.icon.loadImage(on: iconView, targetSize: Constants.iconSize, animated: false)

        titleLabel.text = viewModel.title
        subtitleLabel.text = viewModel.subtitle
        subtitleLabel.isHidden = viewModel.subtitle == nil
        valueLabel.text = viewModel.value

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
        static let iconSize = CGSize(width: 32, height: 32)
        static let chevronSize: CGFloat = 16
        static let minHeight: CGFloat = 64
    }

    func setupLayout() {
        let titleView = UIView.vStack(alignment: .leading, spacing: 2, [titleLabel, subtitleLabel])
        let valueView = UIView.vStack(alignment: .trailing, spacing: 2, [valueLabel, detailLabel])

        let contentView = UIView.hStack(
            alignment: .center,
            spacing: 12,
            [iconView, titleView, UIView(), valueView, chevronView]
        )

        contentView.setCustomSpacing(8, after: valueView)
        contentView.isUserInteractionEnabled = false

        addSubview(contentView)
        contentView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(16)
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

        titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        valueLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        detailLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
    }
}
