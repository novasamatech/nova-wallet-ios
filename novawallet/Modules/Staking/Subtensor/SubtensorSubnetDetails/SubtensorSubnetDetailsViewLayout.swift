import UIKit
import UIKit_iOS

final class SubtensorSubnetDetailsViewLayout: UIView {
    let containerView: ScrollableContainerView = {
        let view = ScrollableContainerView(axis: .vertical, respectsSafeArea: true)
        view.stackView.layoutMargins = UIEdgeInsets(top: 20, left: 16, bottom: 24, right: 16)
        view.stackView.isLayoutMarginsRelativeArrangement = true
        view.stackView.spacing = 16
        return view
    }()

    let priceCaption = UILabel()
    let priceLabel = UILabel()
    let changeLabel = UILabel()
    let currencyButtons: [UIButton] = ["TAO", CurrencyManager.shared?.selectedCurrency.code ?? "Fiat"].map { title in
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = .caption1
        button.setTitleColor(R.color.colorTextPrimary(), for: .normal)
        button.layer.cornerRadius = 8
        return button
    }

    let chartView = SubtensorSubnetPriceChartView()
    let chartLoadingView = SubtensorChartLoadingView()
    let chartStatusLabel = UILabel()
    let periodButtons: [UIButton] = ["1D", "7D", "1M", "3M", "1Y"].map { title in
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = .caption1
        button.setTitleColor(R.color.colorTextSecondary(), for: .normal)
        button.layer.cornerRadius = 8
        return button
    }

    let validatorCaption = UILabel()
    let validatorButton = UIButton(type: .system)
    let estimateCaption = UILabel()
    let estimateCard = UIView()
    let estimateLabel = UILabel()
    let estimateAmountButtons: [UIButton] = ["1 TAO", "5 TAO", "10 TAO", "Max"].map { title in
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = .caption1
        button.setTitleColor(R.color.colorTextPrimary(), for: .normal)
        button.backgroundColor = R.color.colorContainerBackground()
        button.layer.cornerRadius = 8
        return button
    }

    let riskCaption = UILabel()
    let riskCard = UIView()
    let riskLabel = UILabel()
    let detailsCard = UIView()
    let detailsLabel = UILabel()
    let favoriteButton = UIButton(type: .system)
    let actionButton = TriangularedButton()
    let bottomBar = UIView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = R.color.colorSecondaryScreenBackground()
        setupStyles()
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func setupStyles() {
        [priceCaption, validatorCaption, estimateCaption, riskCaption].forEach { label in
            label.font = .caption1
            label.textColor = R.color.colorTextSecondary()
        }
        priceLabel.font = .boldTitle1
        priceLabel.textColor = R.color.colorTextPrimary()
        changeLabel.font = .caption1
        changeLabel.textColor = R.color.colorTextPositive()

        chartStatusLabel.font = .regularFootnote
        chartStatusLabel.textColor = R.color.colorTextSecondary()
        chartStatusLabel.textAlignment = .center
        chartStatusLabel.numberOfLines = 0

        [estimateCard, riskCard, detailsCard].forEach { card in
            card.backgroundColor = R.color.colorBlockBackground()
            card.layer.cornerRadius = 12
        }
        estimateLabel.font = .regularFootnote
        estimateLabel.textColor = R.color.colorTextPrimary()
        estimateLabel.numberOfLines = 0
        riskLabel.font = .regularFootnote
        riskLabel.textColor = R.color.colorTextPrimary()
        riskLabel.numberOfLines = 0
        detailsLabel.font = .regularFootnote
        detailsLabel.textColor = R.color.colorTextSecondary()
        detailsLabel.numberOfLines = 0

        validatorButton.backgroundColor = R.color.colorBlockBackground()
        validatorButton.layer.cornerRadius = 12
        validatorButton.contentHorizontalAlignment = .left
        validatorButton.titleLabel?.font = .regularSubheadline
        validatorButton.setTitleColor(R.color.colorTextPrimary(), for: .normal)
        validatorButton.contentEdgeInsets = UIEdgeInsets(top: 12, left: 16, bottom: 12, right: 16)

        favoriteButton.backgroundColor = R.color.colorBlockBackground()
        favoriteButton.layer.cornerRadius = 10
        actionButton.applyDefaultStyle()
        bottomBar.backgroundColor = R.color.colorSecondaryScreenBackground()
    }

    private func setupLayout() {
        setupFrame()
        setupPriceChart()
        setupInformationCards()
    }

    private func setupFrame() {
        addSubview(containerView)
        addSubview(bottomBar)
        bottomBar.addSubview(favoriteButton)
        bottomBar.addSubview(actionButton)

        bottomBar.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
            make.top.equalTo(actionButton.snp.top).offset(-16)
        }
        favoriteButton.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(16)
            make.centerY.equalTo(actionButton)
            make.size.equalTo(52)
        }
        actionButton.snp.makeConstraints { make in
            make.leading.equalTo(favoriteButton.snp.trailing).offset(8)
            make.trailing.equalToSuperview().inset(16)
            make.bottom.equalTo(safeAreaLayoutGuide).inset(12)
            make.height.equalTo(52)
        }
        containerView.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.bottom.equalTo(bottomBar.snp.top)
        }
    }

    private func setupPriceChart() {
        let priceStack = UIStackView.vStack(alignment: .leading, spacing: 4, [priceCaption, priceLabel, changeLabel])
        let currencyStack = UIStackView(arrangedSubviews: currencyButtons)
        currencyStack.axis = .horizontal
        currencyStack.spacing = 4
        currencyStack.snp.makeConstraints { make in make.width.equalTo(110); make.height.equalTo(30) }
        let headline = UIStackView(arrangedSubviews: [priceStack, UIView(), currencyStack])
        headline.axis = .horizontal
        headline.alignment = .top
        containerView.stackView.addArrangedSubview(headline)

        let chartContainer = UIView()
        chartContainer.addSubview(chartView)
        chartContainer.addSubview(chartLoadingView)
        chartContainer.addSubview(chartStatusLabel)
        chartView.snp.makeConstraints { make in make.edges.equalToSuperview() }
        chartLoadingView.snp.makeConstraints { make in make.edges.equalToSuperview() }
        chartStatusLabel.snp.makeConstraints { make in make.edges.equalToSuperview().inset(16) }
        chartContainer.snp.makeConstraints { make in make.height.equalTo(208) }
        containerView.stackView.addArrangedSubview(chartContainer)

        let periodStack = UIStackView(arrangedSubviews: periodButtons)
        periodStack.axis = .horizontal
        periodStack.distribution = .fillEqually
        periodStack.spacing = 4
        periodStack.snp.makeConstraints { make in make.height.equalTo(32) }
        containerView.stackView.addArrangedSubview(periodStack)
    }

    private func setupInformationCards() {
        let validatorStack = UIStackView.vStack(alignment: .fill, spacing: 8, [validatorCaption, validatorButton])
        containerView.stackView.addArrangedSubview(validatorStack)

        let amountStack = UIStackView(arrangedSubviews: estimateAmountButtons)
        amountStack.axis = .horizontal
        amountStack.distribution = .fillEqually
        amountStack.spacing = 6
        amountStack.snp.makeConstraints { make in make.height.equalTo(32) }
        estimateCard.addSubview(amountStack)
        estimateCard.addSubview(estimateLabel)
        amountStack.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview().inset(12)
        }
        estimateLabel.snp.makeConstraints { make in
            make.top.equalTo(amountStack.snp.bottom).offset(12)
            make.leading.trailing.bottom.equalToSuperview().inset(16)
        }
        let estimateStack = UIStackView.vStack(alignment: .fill, spacing: 8, [estimateCaption, estimateCard])
        containerView.stackView.addArrangedSubview(estimateStack)

        riskCard.addSubview(riskLabel)
        riskLabel.snp.makeConstraints { make in make.edges.equalToSuperview().inset(16) }
        let riskStack = UIStackView.vStack(alignment: .fill, spacing: 8, [riskCaption, riskCard])
        containerView.stackView.addArrangedSubview(riskStack)

        detailsCard.addSubview(detailsLabel)
        detailsLabel.snp.makeConstraints { make in make.edges.equalToSuperview().inset(16) }
        containerView.stackView.addArrangedSubview(detailsCard)
    }
}
