import UIKit
import UIKit_iOS
import SnapKit

typealias SwipeGovBannerTableViewCell = PlainBaseTableViewCell<SwipeGovBannerView>

extension PlainBaseTableViewCell where C == SwipeGovBannerView {
    func setupStyle() {
        backgroundColor = .clear
        selectionStyle = .none
    }
}

// MARK: Banner View

final class SwipeGovBannerView: UIView {
    let gradientBackgroundView: RoundedGradientBackgroundView = .create { view in
        view.cornerRadius = 12
        view.strokeWidth = 2
        view.strokeColor = R.color.colorContainerBorder()!
        view.shadowColor = UIColor.black
        view.shadowOpacity = 0.16
        view.shadowOffset = CGSize(width: 6, height: 4)
        view.bind(model: .swipeGovCell())
    }

    let contentView = SwipeGovBannerContentView()

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()

        backgroundColor = .clear
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        addSubview(gradientBackgroundView)
        gradientBackgroundView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        addSubview(contentView)
        contentView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.top.bottom.equalToSuperview().inset(15)
        }
    }

    func bind(with viewModel: SwipeGovBannerViewModel) {
        contentView.bind(with: viewModel)
    }
}

// MARK: Content View

final class SwipeGovBannerContentView: GenericPairValueView<
    GenericPairValueView<
        UIImageView,
        GenericPairValueView<
            GenericPairValueView<
                UILabel,
                BorderedLabelView
            >,
            UILabel
        >
    >,
    UIImageView
> {
    var iconView: UIImageView {
        fView.fView
    }

    var titleValueView: GenericPairValueView<
        GenericPairValueView<
            UILabel,
            BorderedLabelView
        >,
        UILabel
    > {
        fView.sView
    }

    var titleLabel: UILabel {
        titleValueView.fView.fView
    }

    var counterLabel: BorderedLabelView {
        titleValueView.fView.sView
    }

    var valueLabel: UILabel {
        titleValueView.sView
    }

    var accessoryView: UIImageView {
        sView
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        configure()

        backgroundColor = .clear
    }

    private func configure() {
        setHorizontalAndSpacing(12.0)
        fView.setHorizontalAndSpacing(12.0)
        titleValueView.setVerticalAndSpacing(9.0)
        titleValueView.stackView.alignment = .leading
        titleValueView.fView.setHorizontalAndSpacing(8.0)
        titleValueView.fView.stackView.distribution = .equalCentering

        titleLabel.apply(style: .regularSubhedlinePrimary)
        titleLabel.numberOfLines = 1

        valueLabel.apply(style: .caption1Secondary)
        valueLabel.numberOfLines = 0

        counterLabel.backgroundView.fillColor = R.color.colorChipsBackground()!
        counterLabel.titleLabel.apply(style: .semiboldChip)
        counterLabel.contentInsets = UIEdgeInsets(top: 4, left: 8, bottom: 4, right: 8)
        counterLabel.backgroundView.cornerRadius = 7

        iconView.snp.makeConstraints { make in
            make.width.height.equalTo(72)
        }
        accessoryView.snp.makeConstraints { make in
            make.width.height.equalTo(24)
        }

        accessoryView.image = R.image.iconSmallArrow()?.tinted(with: R.color.colorIconSecondary()!)
        accessoryView.contentMode = .scaleAspectFit

        iconView.image = R.image.iconSwipeGov()
        iconView.contentMode = .scaleAspectFit
    }

    func bind(with viewModel: SwipeGovBannerViewModel) {
        titleLabel.text = viewModel.title
        valueLabel.text = viewModel.description

        if let counterText = viewModel.referendumCounterText {
            counterLabel.titleLabel.text = counterText
            counterLabel.isHidden = false
        } else {
            counterLabel.isHidden = true
        }
    }
}
