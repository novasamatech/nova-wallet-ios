import SnapKit
import UIKit

final class SubtensorValidatorCardView: UIControl {
    let iconView: UIImageView = .create { view in
        view.contentMode = .scaleAspectFit
    }

    let nameLabel: UILabel = .create { label in
        label.apply(style: .semiboldSubhedlinePrimary)
    }

    let subtitleLabel: UILabel = .create { label in
        label.apply(style: .caption1Secondary)
    }

    let rateLabel: UILabel = .create { label in
        label.apply(style: .semiboldSubhedlinePrimary)
        label.textColor = R.color.colorTextPositive()
        label.textAlignment = .right
    }

    let rateCaptionLabel: UILabel = .create { label in
        label.apply(style: .caption1Secondary)
        label.textAlignment = .right
    }

    let chevronView: UIImageView = .create { view in
        view.image = R.image.iconSmallArrow()?.tinted(with: R.color.colorIconSecondary()!)
        view.contentMode = .scaleAspectFit
    }

    private let nameSkeletonView: SubtensorChartLoadingView = .create { view in
        view.layer.cornerRadius = 6
    }

    private let rateSkeletonView: SubtensorChartLoadingView = .create { view in
        view.layer.cornerRadius = 6
    }

    private lazy var rateView = UIView.vStack(alignment: .trailing, spacing: 2, [rateLabel, rateCaptionLabel])

    private lazy var contentView = UIView.hStack(
        alignment: .center,
        spacing: Constants.spacing,
        [iconView, titleView, rateView, chevronView]
    )

    private lazy var titleView = UIView.vStack(alignment: .leading, spacing: 2, [nameLabel, subtitleLabel])

    private var heightConstraint: Constraint?

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

    func applyEmbeddedStyle() {
        backgroundColor = .clear
        layer.cornerRadius = 0

        contentView.snp.updateConstraints { make in
            make.leading.trailing.equalToSuperview().inset(Constants.embeddedHorizontalInset)
        }

        heightConstraint?.update(offset: Constants.embeddedMinHeight)
    }

    func bind(viewModel: SubtensorValidatorCardViewModel) {
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
        case let .value(rate):
            rateView.isHidden = false
            rateLabel.text = rate
            rateCaptionLabel.text = viewModel.rateCaption
            rateSkeletonView.setLoading(false)
        }
    }
}

private extension SubtensorValidatorCardView {
    enum Constants {
        static let iconSize: CGFloat = 32
        static let chevronSize: CGFloat = 20
        static let spacing: CGFloat = 12
        static let horizontalInset: CGFloat = 12
        static let embeddedHorizontalInset: CGFloat = 16
        static let minVerticalInset: CGFloat = 10
        static let minHeight: CGFloat = 64
        static let embeddedMinHeight: CGFloat = 58
        static let titleLineHeight: CGFloat = 20
        static let captionLineHeight: CGFloat = 16
    }

    func setupLayout() {
        contentView.isUserInteractionEnabled = false

        addSubview(contentView)
        contentView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(Constants.horizontalInset)
            make.centerY.equalToSuperview()
            make.top.greaterThanOrEqualToSuperview().inset(Constants.minVerticalInset)
        }

        snp.makeConstraints { make in
            heightConstraint = make.height.greaterThanOrEqualTo(Constants.minHeight).constraint
        }

        iconView.snp.makeConstraints { make in
            make.size.equalTo(Constants.iconSize)
        }

        chevronView.snp.makeConstraints { make in
            make.size.equalTo(Constants.chevronSize)
        }

        [nameLabel, rateLabel].forEach { label in
            label.snp.makeConstraints { $0.height.greaterThanOrEqualTo(Constants.titleLineHeight) }
        }

        [subtitleLabel, rateCaptionLabel].forEach { label in
            label.snp.makeConstraints { $0.height.greaterThanOrEqualTo(Constants.captionLineHeight) }
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
        rateView.setContentHuggingPriority(.required, for: .horizontal)
        rateView.setContentCompressionResistancePriority(.required, for: .horizontal)
    }
}
