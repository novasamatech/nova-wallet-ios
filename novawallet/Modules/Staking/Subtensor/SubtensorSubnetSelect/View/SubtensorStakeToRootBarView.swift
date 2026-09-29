import UIKit
import UIKit_iOS

final class SubtensorStakeToRootBarView: UIControl {
    static let preferredHeight: CGFloat = 64

    let backgroundView: RoundedView = .create { view in
        view.applyFilledBackgroundStyle()
        view.fillColor = R.color.colorBlockBackground()!
        view.highlightedFillColor = R.color.colorCellBackgroundPressed()!
        view.cornerRadius = Constants.cornerRadius
        view.isUserInteractionEnabled = false
    }

    let iconView: UIImageView = .create { view in
        view.contentMode = .scaleAspectFit
    }

    let titleLabel: UILabel = .create { view in
        view.apply(style: .semiboldSubhedlinePrimary)
    }

    let subtitleLabel: UILabel = .create { view in
        view.apply(style: .caption1Secondary)
    }

    let chevronView: UIImageView = .create { view in
        view.image = R.image.iconSmallArrow()?.tinted(with: R.color.colorIconSecondary()!)
        view.contentMode = .scaleAspectFit
    }

    private var iconViewModel: ImageViewModelProtocol?

    override var isHighlighted: Bool {
        didSet {
            backgroundView.set(highlighted: isHighlighted, animated: false)
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        isAccessibilityElement = true
        accessibilityTraits = .button

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(viewModel: SubtensorStakeToRootBarViewModel) {
        iconViewModel?.cancel(on: iconView)
        iconViewModel = viewModel.icon

        viewModel.icon.loadImage(
            on: iconView,
            targetSize: CGSize(width: Constants.iconSize, height: Constants.iconSize),
            animated: true
        )

        titleLabel.text = viewModel.title
        subtitleLabel.text = viewModel.subtitle

        accessibilityLabel = viewModel.title
        accessibilityValue = viewModel.subtitle
    }
}

private extension SubtensorStakeToRootBarView {
    func setupLayout() {
        addSubview(backgroundView)
        backgroundView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        let labelsView = UIView.vStack(spacing: Constants.labelsSpacing, [titleLabel, subtitleLabel])
        labelsView.isUserInteractionEnabled = false

        [iconView, labelsView, chevronView].forEach(addSubview)

        iconView.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(Constants.horizontalInset)
            make.centerY.equalToSuperview()
            make.size.equalTo(Constants.iconSize)
        }

        chevronView.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(Constants.chevronInset)
            make.centerY.equalToSuperview()
            make.size.equalTo(Constants.chevronSize)
        }

        labelsView.snp.makeConstraints { make in
            make.leading.equalTo(iconView.snp.trailing).offset(Constants.contentSpacing)
            make.trailing.lessThanOrEqualTo(chevronView.snp.leading).offset(-Constants.contentSpacing)
            make.centerY.equalToSuperview()
        }
    }

    enum Constants {
        static let cornerRadius: CGFloat = 12
        static let horizontalInset: CGFloat = 16
        static let chevronInset: CGFloat = 12
        static let iconSize: CGFloat = 32
        static let chevronSize: CGFloat = 20
        static let contentSpacing: CGFloat = 12
        static let labelsSpacing: CGFloat = 2
    }
}
