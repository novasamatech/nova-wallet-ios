import UIKit
import UIKit_iOS

final class SubtensorStakingStrategyCell: UICollectionViewCell {
    var onChoose: (() -> Void)?

    private let cardBackgroundView = SubtensorStakingStrategyBackgroundView()

    private let badgeContainerView: UIView = .create { view in
        view.backgroundColor = UIColor.white.withAlphaComponent(Constants.badgeBackgroundAlpha)
        view.layer.cornerRadius = Constants.badgeCornerRadius
    }

    private let badgeLabel: UILabel = .create { view in
        view.font = .semiBoldCaps2
        view.textColor = UIColor.white.withAlphaComponent(Constants.primaryTextAlpha)
    }

    private let chartView = SubtensorStakingStrategyChartView()

    private let titleLabel = UILabel(style: .boldTitle2Primary, numberOfLines: 1)

    private let subtitleLabel: UILabel = .create { view in
        view.font = .regularSubheadline
        view.textColor = R.color.colorTextSecondary()
    }

    private let detailsLabel = UILabel(style: .regularSubhedlinePrimary, numberOfLines: 3)

    private let annualReturnView: UIView = .create { view in
        view.backgroundColor = UIColor.white.withAlphaComponent(Constants.annualReturnBackgroundAlpha)
        view.layer.cornerRadius = Constants.annualReturnCornerRadius
    }

    private let annualReturnLabel: UILabel = .create { view in
        view.font = .boldTitle2
        view.textColor = R.color.colorTextPositive()
    }

    private let annualReturnTitleLabel = UILabel(style: .regularSubhedlinePrimary, numberOfLines: 1)

    private let annualReturnDetailsLabel: UILabel = .create { view in
        view.font = .caption1
        view.textColor = R.color.colorTextSecondary()
    }

    private let rangeView = SubtensorStakingStrategyRangeView()

    private let chooseButton: RoundedButton = .create { button in
        button.applyPrimaryStyle()
        button.roundedBackgroundView?.cornerRadius = Constants.buttonCornerRadius
        button.imageWithTitleView?.titleFont = .semiBoldSubheadline
    }

    private let inactiveOverlayView: UIView = .create { view in
        view.backgroundColor = R.color.colorSecondaryScreenBackground()
        view.layer.cornerRadius = Constants.cornerRadius
        view.isUserInteractionEnabled = false
        view.alpha = 0
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
        setupActions()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()

        onChoose = nil
    }

    func bind(viewModel: SubtensorStakingStrategyCardViewModel, chooseTitle: String) {
        let theme = Theme(kind: viewModel.kind)

        cardBackgroundView.bind(baseColor: theme.baseColor, accentColor: theme.accentColor)

        badgeLabel.attributedText = NSAttributedString(
            string: viewModel.badge,
            attributes: [.kern: Constants.badgeLetterSpacing]
        )
        titleLabel.text = viewModel.title
        subtitleLabel.text = viewModel.subtitle
        detailsLabel.text = viewModel.details
        annualReturnLabel.text = viewModel.annualReturn
        annualReturnTitleLabel.text = viewModel.annualReturnTitle
        annualReturnDetailsLabel.text = viewModel.annualReturnDetails
        rangeView.bind(viewModel: viewModel.range)
        chartView.bind(values: viewModel.chartValues)
        chooseButton.imageWithTitleView?.title = chooseTitle
    }

    func animateChartAppearance() {
        chartView.animateAppearance()
    }

    func setInactiveProgress(_ progress: CGFloat) {
        inactiveOverlayView.alpha = min(max(progress, 0), 1) * Constants.inactiveTintAlpha
    }
}

private extension SubtensorStakingStrategyCell {
    func setupActions() {
        chooseButton.addTarget(self, action: #selector(actionChoose), for: .touchUpInside)
    }

    @objc func actionChoose() {
        onChoose?()
    }

    func setupLayout() {
        addSubviews()
        setupTopContentLayout()
        setupBottomContentLayout()
    }

    func addSubviews() {
        contentView.addSubview(cardBackgroundView)
        contentView.addSubview(badgeContainerView)
        badgeContainerView.addSubview(badgeLabel)
        contentView.addSubview(chartView)
        contentView.addSubview(titleLabel)
        contentView.addSubview(subtitleLabel)
        contentView.addSubview(detailsLabel)
        contentView.addSubview(annualReturnView)
        annualReturnView.addSubview(annualReturnLabel)
        annualReturnView.addSubview(annualReturnTitleLabel)
        annualReturnView.addSubview(annualReturnDetailsLabel)
        contentView.addSubview(rangeView)
        contentView.addSubview(chooseButton)
        contentView.addSubview(inactiveOverlayView)
    }

    func setupTopContentLayout() {
        cardBackgroundView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        inactiveOverlayView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        badgeContainerView.snp.makeConstraints { make in
            make.top.leading.equalToSuperview().inset(Constants.badgeOffset)
            make.height.equalTo(Constants.badgeHeight)
        }

        badgeLabel.snp.makeConstraints { make in
            make.top.bottom.equalToSuperview().inset(Constants.badgeVerticalInset)
            make.leading.trailing.equalToSuperview().inset(Constants.badgeHorizontalInset)
        }

        chartView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(Constants.chartTopOffset)
            make.leading.trailing.equalToSuperview().inset(Constants.contentInset)
            make.height.equalTo(Constants.chartHeight)
        }

        titleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(Constants.titleTopOffset)
            make.leading.trailing.equalToSuperview().inset(Constants.contentInset)
        }

        subtitleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(Constants.subtitleTopOffset)
            make.leading.trailing.equalToSuperview().inset(Constants.contentInset)
        }

        detailsLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(Constants.detailsTopOffset)
            make.leading.trailing.equalToSuperview().inset(Constants.contentInset)
        }
    }

    func setupBottomContentLayout() {
        annualReturnView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(Constants.annualReturnTopOffset)
            make.leading.trailing.equalToSuperview().inset(Constants.contentInset)
            make.height.equalTo(Constants.annualReturnHeight)
        }

        annualReturnLabel.snp.makeConstraints { make in
            make.top.leading.equalToSuperview().inset(Constants.annualReturnInset)
        }

        annualReturnTitleLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(Constants.annualReturnTitleLeading)
            make.top.equalToSuperview().offset(Constants.annualReturnTitleTop)
        }

        annualReturnDetailsLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(Constants.annualReturnInset)
            make.top.equalToSuperview().offset(Constants.annualReturnDetailsTop)
        }

        rangeView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(Constants.rangeTopOffset)
            make.leading.trailing.equalToSuperview().inset(Constants.contentInset)
            make.height.equalTo(Constants.rangeHeight)
        }

        chooseButton.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(Constants.buttonTopOffset)
            make.leading.trailing.equalToSuperview().inset(Constants.contentInset)
            make.height.equalTo(Constants.buttonHeight)
        }
    }
}

private extension SubtensorStakingStrategyCell {
    struct Theme {
        let baseColor: UIColor
        let accentColor: UIColor

        init(kind: SubtensorStakingStrategy.Kind) {
            switch kind {
            case .steady:
                baseColor = UIColor(hex: "#132034")!
                accentColor = UIColor(hex: "#3A5D94")!
            case .balanced:
                baseColor = UIColor(hex: "#151635")!
                accentColor = UIColor(hex: "#3B3D7C")!
            case .higherUpside:
                baseColor = UIColor(hex: "#23172E")!
                accentColor = UIColor(hex: "#58378E")!
            }
        }
    }

    enum Constants {
        static let cornerRadius: CGFloat = 16
        static let contentInset: CGFloat = 20
        static let badgeOffset: CGFloat = 12
        static let badgeHeight: CGFloat = 21
        static let badgeVerticalInset: CGFloat = 4
        static let badgeHorizontalInset: CGFloat = 8
        static let badgeCornerRadius: CGFloat = 6
        static let badgeBackgroundAlpha: CGFloat = 0.14
        static let badgeLetterSpacing: CGFloat = 0.6
        static let primaryTextAlpha: CGFloat = 0.88
        static let chartTopOffset: CGFloat = 44
        static let chartHeight: CGFloat = 140
        static let titleTopOffset: CGFloat = 196
        static let subtitleTopOffset: CGFloat = 230
        static let detailsTopOffset: CGFloat = 256
        static let annualReturnTopOffset: CGFloat = 330
        static let annualReturnHeight: CGFloat = 72
        static let annualReturnCornerRadius: CGFloat = 12
        static let annualReturnBackgroundAlpha: CGFloat = 0.08
        static let annualReturnInset: CGFloat = 16
        static let annualReturnTitleLeading: CGFloat = 96
        static let annualReturnTitleTop: CGFloat = 20
        static let annualReturnDetailsTop: CGFloat = 46
        static let rangeTopOffset: CGFloat = 414
        static let rangeHeight: CGFloat = 28
        static let buttonTopOffset: CGFloat = 456
        static let buttonHeight: CGFloat = 52
        static let buttonCornerRadius: CGFloat = 12
        static let inactiveTintAlpha: CGFloat = 0.16
    }
}

private final class SubtensorStakingStrategyBackgroundView: UIView {
    private let firstGradientLayer = CAGradientLayer()
    private let secondGradientLayer = CAGradientLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)

        layer.cornerRadius = Constants.cornerRadius
        layer.masksToBounds = true
        layer.addSublayer(firstGradientLayer)
        layer.addSublayer(secondGradientLayer)

        configure(
            layer: firstGradientLayer,
            startPoint: CGPoint(x: 0, y: 0.879),
            endPoint: CGPoint(x: 1, y: 0.121),
            locations: [0.11328, 0.56663]
        )
        configure(
            layer: secondGradientLayer,
            startPoint: CGPoint(x: 0.934, y: 0),
            endPoint: CGPoint(x: 0.066, y: 1),
            locations: [0.042787, 0.44275]
        )
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        firstGradientLayer.frame = bounds
        secondGradientLayer.frame = bounds
    }

    func bind(baseColor: UIColor, accentColor: UIColor) {
        layer.backgroundColor = baseColor.cgColor

        let transparentBase = baseColor.withAlphaComponent(0)
        let colors = [accentColor.cgColor, transparentBase.cgColor]
        firstGradientLayer.colors = colors
        secondGradientLayer.colors = colors
    }
}

private extension SubtensorStakingStrategyBackgroundView {
    func configure(
        layer: CAGradientLayer,
        startPoint: CGPoint,
        endPoint: CGPoint,
        locations: [NSNumber]
    ) {
        layer.startPoint = startPoint
        layer.endPoint = endPoint
        layer.locations = locations
        layer.drawsAsynchronously = false
    }

    enum Constants {
        static let cornerRadius: CGFloat = 16
    }
}
