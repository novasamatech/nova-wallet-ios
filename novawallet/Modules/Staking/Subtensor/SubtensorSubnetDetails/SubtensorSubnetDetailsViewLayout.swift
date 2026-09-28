import DGCharts
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

final class SubtensorSubnetPriceChartView: UIView {
    enum Style {
        case price
        case portfolio
    }

    private let chart = LineChartView()
    private let style: Style

    init(style: Style = .price) {
        self.style = style
        super.init(frame: .zero)
        addSubview(chart)
        chart.snp.makeConstraints { make in make.edges.equalToSuperview() }
        chart.backgroundColor = .clear
        chart.chartDescription.enabled = false
        chart.legend.enabled = false
        chart.leftAxis.enabled = false
        chart.xAxis.enabled = false
        chart.setScaleEnabled(false)
        chart.dragEnabled = false
        chart.highlightPerTapEnabled = false
        chart.minOffset = 0
        chart.extraTopOffset = 8
        chart.extraBottomOffset = 8

        let axis = chart.rightAxis
        axis.enabled = true
        axis.labelFont = .caption1
        axis.labelTextColor = R.color.colorTextSecondary()!
        axis.labelPosition = .outsideChart
        axis.drawAxisLineEnabled = false
        axis.drawGridLinesEnabled = style == .portfolio
        axis.gridColor = R.color.colorChartGridLine()!
        axis.gridLineDashLengths = [2, 3]
        axis.gridLineWidth = 0.5
        axis.setLabelCount(3, force: true)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func bind(points: [SubtensorPricePoint], inFiat: Bool = false) {
        bind(
            values: points.map { NSDecimalNumber(decimal: inFiat ? $0.fiatPerAlpha : $0.taoPerAlpha).doubleValue },
            showsCurrency: inFiat
        )
    }

    func bind(values: [Double], showsCurrency: Bool = false) {
        let finiteValues = values.filter { $0.isFinite }
        guard !finiteValues.isEmpty, let minimum = finiteValues.min(), let maximum = finiteValues.max() else {
            chart.data = nil
            return
        }

        let spread = max(maximum - minimum, abs(maximum) * 0.02, 0.000_001)
        let padding = spread * 0.12
        let lower = minimum - padding
        let upper = maximum + padding
        chart.rightAxis.axisMinimum = lower
        chart.rightAxis.axisMaximum = upper
        chart.rightAxis.removeAllLimitLines()
        if style == .price {
            let guide = ChartLimitLine(limit: (lower + upper) / 2)
            guide.lineColor = R.color.colorChartGridLine()!
            guide.lineWidth = 0.5
            guide.lineDashLengths = [2, 3]
            guide.drawLabelEnabled = false
            chart.rightAxis.addLimitLine(guide)
            chart.rightAxis.drawLimitLinesBehindDataEnabled = true
        }

        let formatter = DefaultAxisValueFormatter()
        let style = style
        let currencySymbol = CurrencyManager.shared?.selectedCurrency.symbol ?? "$"
        let largestMagnitude = max(abs(lower), abs(upper))
        let decimals = largestMagnitude >= 1 ? 2
            : largestMagnitude >= 0.1 ? 3
            : largestMagnitude >= 0.01 ? 4
            : largestMagnitude >= 0.001 ? 5 : 6
        formatter.block = { value, _ in
            if style == .price {
                if abs(value - (lower + upper) / 2) < spread * 0.01 { return "" }
                let number = String(format: "%.*f", decimals, value)
                return showsCurrency ? currencySymbol + number : number
            }
            if abs(value) >= 1000 {
                return String(format: "%@%.1fk", currencySymbol, value / 1000)
            }
            return String(format: "%@%.0f", currencySymbol, value)
        }
        chart.rightAxis.valueFormatter = formatter

        let entries = finiteValues.enumerated().map { index, value in
            ChartDataEntry(x: Double(index), y: value)
        }
        let line = LineChartDataSet(entries: entries)
        line.mode = .linear
        line.axisDependency = .right
        line.setColor(R.color.colorTextPositive()!)
        line.lineWidth = 1.5
        line.drawCirclesEnabled = false
        line.drawValuesEnabled = false
        line.highlightEnabled = false
        line.drawFilledEnabled = true
        let fillColor = style == .portfolio
            ? R.color.colorButtonBackgroundPrimary()! : R.color.colorTextPositive()!
        if let gradient = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: [fillColor.withAlphaComponent(0).cgColor, fillColor.withAlphaComponent(0.28).cgColor] as CFArray,
            locations: [0, 1]
        ) {
            line.fillAlpha = 1
            line.fill = LinearGradientFill(gradient: gradient, angle: 90)
        }
        chart.data = LineChartData(dataSet: line)
        chart.notifyDataSetChanged()
    }
}

final class SubtensorChartLoadingView: UIView, SkeletonableView {
    var skeletonView: SkrullableView?
    var skeletonSuperview: UIView { self }
    var hidingViews: [UIView] { [] }

    private var loading = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        layer.cornerRadius = 12
        clipsToBounds = true
        isHidden = true
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        if loading { updateLoadingState() }
    }

    func setLoading(_ value: Bool) {
        loading = value
        isHidden = !value
        if value { startLoadingIfNeeded() } else { stopLoadingIfNeeded() }
    }

    func createSkeletons(for size: CGSize) -> [Skeletonable] {
        [SingleSkeleton.createRow(
            on: self,
            containerView: self,
            spaceSize: size,
            offset: .zero,
            size: size
        )]
    }
}
