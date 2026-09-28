import UIKit
import UIKit_iOS

final class SubtensorPortfolioViewLayout: UIView {
    let backgroundView = MultigradientView.background
    let containerView: ScrollableContainerView = {
        let view = ScrollableContainerView(axis: .vertical, respectsSafeArea: true)
        view.stackView.layoutMargins = UIEdgeInsets(top: 16, left: 16, bottom: 20, right: 16)
        view.stackView.isLayoutMarginsRelativeArrangement = true
        view.stackView.spacing = 16
        return view
    }()

    let totalCard = UIView()
    let totalCaption = UILabel()
    let totalLabel = UILabel()
    let fiatLabel = UILabel()
    let changeLabel = UILabel()
    let chartView = SubtensorSubnetPriceChartView(style: .portfolio)
    let chartLoadingView = SubtensorChartLoadingView()
    let chartStatusLabel = UILabel()
    let chartNoteLabel = UILabel()
    let periodButtons: [UIButton] = ["1D", "7D", "30D", "1Y", "All"].map { title in
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = .caption1
        button.setTitleColor(R.color.colorTextSecondary(), for: .normal)
        button.layer.cornerRadius = 8
        return button
    }

    let positionsCaption = UILabel()
    let positionsStack = UIStackView()
    let emptyLabel = UILabel()
    let syncNoticeButton = UIButton(type: .system)
    let addButton = TriangularedButton()
    let bottomBar = UIView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = R.color.colorSecondaryScreenBackground()
        setupStyles()
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func bind(rows: [SubtensorPortfolioRowViewModel], action: @escaping (Int) -> Void) {
        emptyLabel.isHidden = !rows.isEmpty
        positionsStack.arrangedSubviews.forEach { view in
            positionsStack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }
        for (index, row) in rows.enumerated() {
            let view = SubtensorPortfolioPositionRow()
            view.bind(row)
            view.action = { action(index) }
            positionsStack.addArrangedSubview(view)
        }
    }

    private func setupStyles() {
        totalCard.backgroundColor = R.color.colorBlockBackground()
        totalCard.layer.cornerRadius = 12
        totalCaption.font = .regularFootnote
        totalCaption.textColor = R.color.colorTextSecondary()
        totalLabel.font = .boldTitle1
        totalLabel.textColor = R.color.colorTextPrimary()
        fiatLabel.font = .regularFootnote
        fiatLabel.textColor = R.color.colorTextSecondary()
        changeLabel.font = .caption1
        changeLabel.textColor = R.color.colorTextPositive()
        chartStatusLabel.font = .regularFootnote
        chartStatusLabel.textColor = R.color.colorTextSecondary()
        chartStatusLabel.textAlignment = .center
        chartNoteLabel.font = .caption1
        chartNoteLabel.textColor = R.color.colorTextSecondary()
        chartNoteLabel.numberOfLines = 0
        positionsCaption.font = .caption1
        positionsCaption.textColor = R.color.colorTextSecondary()
        positionsStack.axis = .vertical
        positionsStack.spacing = 8
        emptyLabel.font = .regularFootnote
        emptyLabel.textColor = R.color.colorTextSecondary()
        emptyLabel.textAlignment = .center
        syncNoticeButton.backgroundColor = R.color.colorBlockBackground()
        syncNoticeButton.layer.cornerRadius = 12
        syncNoticeButton.setTitleColor(R.color.colorTextPrimary(), for: .normal)
        syncNoticeButton.isHidden = true
        syncNoticeButton.snp.makeConstraints { make in make.height.equalTo(48) }
        addButton.applyDefaultStyle()
        bottomBar.backgroundColor = R.color.colorSecondaryScreenBackground()
    }

    private func setupLayout() {
        addSubview(backgroundView)
        backgroundView.snp.makeConstraints { make in make.edges.equalToSuperview() }
        addSubview(containerView)
        addSubview(bottomBar)
        bottomBar.addSubview(addButton)
        bottomBar.snp.makeConstraints { make in make.leading.trailing.bottom.equalToSuperview() }
        addButton.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(16)
            make.top.equalToSuperview().offset(16)
            make.bottom.equalTo(safeAreaLayoutGuide).inset(12)
            make.height.equalTo(52)
        }
        containerView.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.bottom.equalTo(bottomBar.snp.top)
        }

        setupTotalCard()
        containerView.stackView.addArrangedSubview(totalCard)
        containerView.stackView.addArrangedSubview(syncNoticeButton)

        addButton.invalidateLayout()
        containerView.stackView.addArrangedSubview(positionsCaption)
        containerView.stackView.addArrangedSubview(positionsStack)
        containerView.stackView.addArrangedSubview(emptyLabel)
    }

    private func setupTotalCard() {
        totalCard.addSubview(totalCaption)
        totalCard.addSubview(totalLabel)
        totalCard.addSubview(fiatLabel)
        totalCard.addSubview(changeLabel)
        totalCard.addSubview(chartView)
        totalCard.addSubview(chartLoadingView)
        totalCard.addSubview(chartStatusLabel)
        totalCard.addSubview(chartNoteLabel)
        let periodStack = UIStackView(arrangedSubviews: periodButtons)
        periodStack.axis = .horizontal
        periodStack.distribution = .fillEqually
        totalCard.addSubview(periodStack)

        totalCaption.snp.makeConstraints { make in make.top.leading.equalToSuperview().inset(16) }
        totalLabel.snp.makeConstraints { make in
            make.top.equalTo(totalCaption.snp.bottom).offset(2)
            make.leading.equalTo(totalCaption)
        }
        fiatLabel.snp.makeConstraints { make in
            make.leading.equalTo(totalLabel.snp.trailing).offset(8)
            make.lastBaseline.equalTo(totalLabel)
        }
        changeLabel.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(16)
            make.centerY.equalTo(totalCaption)
        }
        chartView.snp.makeConstraints { make in
            make.top.equalTo(totalLabel.snp.bottom).offset(14)
            make.leading.trailing.equalToSuperview().inset(12)
            make.height.equalTo(120)
        }
        chartLoadingView.snp.makeConstraints { make in make.edges.equalTo(chartView) }
        chartStatusLabel.snp.makeConstraints { make in make.edges.equalTo(chartView) }
        periodStack.snp.makeConstraints { make in
            make.top.equalTo(chartView.snp.bottom).offset(10)
            make.leading.trailing.equalToSuperview().inset(12)
            make.height.equalTo(32)
        }
        chartNoteLabel.snp.makeConstraints { make in
            make.top.equalTo(periodStack.snp.bottom).offset(4)
            make.leading.trailing.equalToSuperview().inset(16)
            make.bottom.equalToSuperview().inset(8)
        }
    }
}

final class SubtensorPortfolioPositionRow: UIControl {
    let titleLabel = UILabel()
    let subtitleLabel = UILabel()
    let valueLabel = UILabel()
    let amountLabel = UILabel()
    var action: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = R.color.colorBlockBackground()
        layer.cornerRadius = 12
        titleLabel.font = .semiBoldSubheadline
        titleLabel.textColor = R.color.colorTextPrimary()
        subtitleLabel.font = .caption1
        subtitleLabel.textColor = R.color.colorTextSecondary()
        valueLabel.font = .semiBoldSubheadline
        valueLabel.textColor = R.color.colorTextPrimary()
        amountLabel.font = .caption1
        amountLabel.textColor = R.color.colorTextSecondary()
        valueLabel.textAlignment = .right
        amountLabel.textAlignment = .right

        let titleStack = UIStackView.vStack(alignment: .leading, spacing: 2, [titleLabel, subtitleLabel])
        let valueStack = UIStackView.vStack(alignment: .trailing, spacing: 2, [valueLabel, amountLabel])
        addSubview(titleStack)
        addSubview(valueStack)
        titleStack.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(16)
            make.centerY.equalToSuperview()
            make.trailing.lessThanOrEqualTo(valueStack.snp.leading).offset(-8)
        }
        valueStack.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(16)
            make.centerY.equalToSuperview()
        }
        snp.makeConstraints { make in make.height.equalTo(64) }
        addTarget(self, action: #selector(didTap), for: .touchUpInside)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func bind(_ row: SubtensorPortfolioRowViewModel) {
        titleLabel.text = row.title
        subtitleLabel.text = row.subtitle
        valueLabel.text = row.value
        amountLabel.text = row.amount
    }

    @objc private func didTap() { action?() }
}
