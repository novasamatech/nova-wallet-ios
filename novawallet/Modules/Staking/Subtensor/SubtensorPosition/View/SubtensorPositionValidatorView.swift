import UIKit

final class SubtensorPositionValidatorView: UIControl {
    let iconView: UIImageView = .create { view in
        view.contentMode = .scaleAspectFit
    }

    let nameLabel: UILabel = .create { label in
        label.apply(style: .semiboldBodyPrimary)
    }

    let subtitleLabel: UILabel = .create { label in
        label.apply(style: .footnoteSecondary)
    }

    let rateLabel: UILabel = .create { label in
        label.apply(style: .semiboldBodyPrimary)
        label.textColor = R.color.colorTextPositive()
        label.textAlignment = .right
    }

    let rateCaptionLabel: UILabel = .create { label in
        label.apply(style: .caption1Secondary)
        label.textAlignment = .right
    }

    let chevronView: UIImageView = .create { view in
        view.image = R.image.iconChevronRight()?.tinted(with: R.color.colorIconSecondary()!)
        view.contentMode = .scaleAspectFit
    }

    private let nameSkeletonView: SubtensorChartLoadingView = .create { view in
        view.layer.cornerRadius = 6
    }

    private let rateSkeletonView: SubtensorChartLoadingView = .create { view in
        view.layer.cornerRadius = 6
    }

    private lazy var rateView = UIView.vStack(alignment: .trailing, spacing: 2, [rateLabel, rateCaptionLabel])

    private var iconViewModel: ImageViewModelProtocol?

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

    func bind(viewModel: SubtensorPositionValidatorViewModel) {
        iconViewModel?.cancel(on: iconView)
        iconViewModel = viewModel.icon
        iconView.image = nil
        viewModel.icon?.loadImage(
            on: iconView,
            targetSize: CGSize(width: Constants.iconSize, height: Constants.iconSize),
            animated: false
        )

        nameLabel.text = viewModel.name
        nameSkeletonView.setLoading(viewModel.name == nil)
        subtitleLabel.text = viewModel.subtitle

        switch viewModel.rate {
        case .loading:
            rateView.isHidden = false
            rateLabel.text = nil
            rateCaptionLabel.text = nil
            rateSkeletonView.setLoading(true)
        case .hidden:
            rateView.isHidden = true
            rateSkeletonView.setLoading(false)
        case let .loaded(rate):
            rateView.isHidden = false
            rateLabel.text = rate
            rateCaptionLabel.text = viewModel.rateCaption
            rateSkeletonView.setLoading(false)
        }
    }
}

private extension SubtensorPositionValidatorView {
    enum Constants {
        static let iconSize: CGFloat = 32
        static let chevronSize: CGFloat = 16
        static let minHeight: CGFloat = 64
    }

    func setupLayout() {
        let titleView = UIView.vStack(alignment: .leading, spacing: 2, [nameLabel, subtitleLabel])

        let contentView = UIView.hStack(
            alignment: .center,
            spacing: 12,
            [iconView, titleView, UIView(), rateView, chevronView]
        )

        contentView.setCustomSpacing(8, after: rateView)
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

        nameLabel.snp.makeConstraints { make in
            make.height.greaterThanOrEqualTo(20)
        }

        rateLabel.snp.makeConstraints { make in
            make.height.greaterThanOrEqualTo(20)
        }

        addSubview(nameSkeletonView)
        nameSkeletonView.snp.makeConstraints { make in
            make.leading.centerY.equalTo(nameLabel)
            make.width.equalTo(100)
            make.height.equalTo(12)
        }

        addSubview(rateSkeletonView)
        rateSkeletonView.snp.makeConstraints { make in
            make.trailing.centerY.equalTo(rateLabel)
            make.width.equalTo(40)
            make.height.equalTo(12)
        }

        titleView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        rateView.setContentCompressionResistancePriority(.required, for: .horizontal)
    }
}
