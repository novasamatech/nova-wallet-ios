import Foundation_iOS
import UIKit

final class SubtensorSubnetDetailsViewController: UIViewController, ViewHolder {
    typealias RootViewType = SubtensorSubnetDetailsViewLayout

    let presenter: SubtensorSubnetDetailsPresenterProtocol
    let target: SubtensorStakeTarget
    private var inFiat = false
    private var history: SubtensorPriceHistory?
    private var taoPriceText: String?
    private var weeklyChangeText: String?
    private var selectedPeriod: SubtensorPricePeriod = .week
    private var selectedEstimateAmount: Decimal = 5

    init(
        presenter: SubtensorSubnetDetailsPresenterProtocol,
        target: SubtensorStakeTarget,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.presenter = presenter
        self.target = target
        super.init(nibName: nil, bundle: nil)
        self.localizationManager = localizationManager
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func loadView() { view = SubtensorSubnetDetailsViewLayout() }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupContent()
        setupActions()
        presenter.setup()
    }

    private func setupContent() {
        setupLocalization()

        rootView.periodButtons[1].backgroundColor = R.color.colorBlockBackground()
        rootView.currencyButtons[0].backgroundColor = R.color.colorBlockBackground()
        rootView.estimateAmountButtons[1].backgroundColor = R.color.colorButtonBackgroundPrimary()
        rootView.estimateAmountButtons[3].isEnabled = false
        if target.isRoot {
            rootView.chartView.isHidden = true
            rootView.chartStatusLabel.text = R.string(
                preferredLanguages: selectedLocale.rLanguages
            ).localizable.stakingSubtensorUiDetailRootChart()
            rootView.periodButtons.forEach { $0.isHidden = true }
            rootView.favoriteButton.isHidden = true
        }
    }

    private func setupLocalization() {
        let strings = R.string(preferredLanguages: selectedLocale.rLanguages).localizable
        rootView.priceCaption.text = target.isRoot
            ? strings.stakingSubtensorUiRootStaking() : strings.stakingSubtensorUiDetailPrice()
        rootView.validatorCaption.text = strings.stakingSubtensorUiDetailValidator()
        rootView.validatorButton.setTitle(strings.stakingSubtensorUiDetailChooseValidator(), for: .normal)
        rootView.estimateCaption.text = strings.stakingSubtensorUiDetailEstimate()
        rootView.riskCaption.text = strings.stakingSubtensorUiDetailSafer()
        if rootView.riskLabel.text == nil {
            rootView.riskLabel.text = strings.stakingSubtensorUiDetailRiskLoading()
        }
        rootView.detailsLabel.text = strings.stakingSubtensorUiDetailMoreFormat(Int(target.netuid))
        rootView.actionButton.imageWithTitleView?.title = target.isRoot
            ? strings.stakingSubtensorUiDetailUseRoot() : strings.stakingSubtensorUiDetailUseSubnet()
        rootView.actionButton.invalidateLayout()
        updateEstimate()
    }

    private func setupActions() {
        rootView.actionButton.addTarget(self, action: #selector(actionContinue), for: .touchUpInside)
        rootView.favoriteButton.addTarget(self, action: #selector(actionFavorite), for: .touchUpInside)
        rootView.validatorButton.addTarget(self, action: #selector(actionValidator), for: .touchUpInside)
        for (index, button) in rootView.periodButtons.enumerated() {
            button.tag = index
            button.addTarget(self, action: #selector(actionPeriod(_:)), for: .touchUpInside)
        }
        for (index, button) in rootView.currencyButtons.enumerated() {
            button.tag = index
            button.addTarget(self, action: #selector(actionCurrency(_:)), for: .touchUpInside)
        }
        for (index, button) in rootView.estimateAmountButtons.enumerated() {
            button.tag = index
            button.addTarget(self, action: #selector(actionEstimateAmount(_:)), for: .touchUpInside)
        }
    }

    @objc private func actionContinue() { presenter.continueStaking() }
    @objc private func actionFavorite() { presenter.toggleFavorite() }
    @objc private func actionValidator() { presenter.selectValidator() }
    @objc private func actionCurrency(_ sender: UIButton) {
        inFiat = sender.tag == 1
        rootView.currencyButtons.forEach { $0.backgroundColor = .clear }
        sender.backgroundColor = R.color.colorBlockBackground()
        renderPrice()
        if let history { rootView.chartView.bind(points: history.points, inFiat: inFiat) }
        updateChangeLabel()
    }

    @objc private func actionEstimateAmount(_ sender: UIButton) {
        let amounts: [Decimal] = [1, 5, 10]
        guard amounts.indices.contains(sender.tag) else { return }
        selectedEstimateAmount = amounts[sender.tag]
        rootView.estimateAmountButtons.forEach { $0.backgroundColor = R.color.colorContainerBackground() }
        sender.backgroundColor = R.color.colorButtonBackgroundPrimary()
        updateEstimate()
    }

    private func updateEstimate() {
        guard !target.isRoot,
              let price = target.listedPrice,
              let priceInTao = Decimal(string: String(price)),
              priceInTao > 0 else {
            rootView.estimateLabel.text = R.string(
                preferredLanguages: selectedLocale.rLanguages
            ).localizable.stakingSubtensorUiDetailRootEstimate()
            return
        }
        let alpha = selectedEstimateAmount * 1_000_000_000 / priceInTao
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 2
        let amount = formatter.string(from: NSDecimalNumber(decimal: alpha)) ?? alpha.description
        let symbol = target.subnetInfo?.displaySymbol ?? "α"
        rootView.estimateLabel.text = R.string(
            preferredLanguages: selectedLocale.rLanguages
        ).localizable.stakingSubtensorUiDetailEstimateAmountFormat(amount, symbol)
    }

    private func renderPrice() {
        if inFiat, let point = history?.points.last {
            let formatter = NumberFormatter()
            formatter.numberStyle = .currency
            formatter.currencyCode = CurrencyManager.shared?.selectedCurrency.code
            rootView.priceLabel.text = formatter.string(from: NSDecimalNumber(decimal: point.fiatPerAlpha))
        } else {
            rootView.priceLabel.text = taoPriceText.map { "\($0) TAO" }
        }
    }

    private func updateChangeLabel() {
        let change = inFiat ? history?.changeInFiat : history?.changeInTao
        if let change {
            let percent = NSDecimalNumber(decimal: change * 100).doubleValue
            let period: String
            switch selectedPeriod {
            case .day: period = "1D"
            case .week: period = "7D"
            case .month: period = "1M"
            case .quarter: period = "3M"
            case .year: period = "1Y"
            case .all: period = "All"
            }
            rootView.changeLabel.text = String(format: "%+.1f%% · %@", percent, period)
            rootView.changeLabel.textColor = change < 0 ? R.color.colorTextNegative() : R.color.colorTextPositive()
        } else {
            rootView.changeLabel.text = selectedPeriod == .week ? weeklyChangeText.map { "\($0) · 7D" } : nil
        }
        rootView.changeLabel.isHidden = rootView.changeLabel.text == nil
    }

    @objc private func actionPeriod(_ sender: UIButton) {
        let periods: [SubtensorPricePeriod] = [.day, .week, .month, .quarter, .year]
        guard periods.indices.contains(sender.tag) else { return }
        selectedPeriod = periods[sender.tag]
        rootView.periodButtons.forEach { $0.backgroundColor = .clear }
        sender.backgroundColor = R.color.colorBlockBackground()
        history = nil
        updateChangeLabel()
        presenter.selectPeriod(periods[sender.tag])
    }
}

extension SubtensorSubnetDetailsViewController: SubtensorSubnetDetailsViewProtocol {
    func didReceive(title: String, price: String?, change: String?, subtitle: String) {
        self.title = title
        taoPriceText = price
        weeklyChangeText = change
        renderPrice()
        if price == nil { rootView.priceLabel.text = subtitle }
        updateChangeLabel()
    }

    func didReceive(history: SubtensorPriceHistoryResult?) {
        guard !target.isRoot else { return }
        switch history {
        case let .available(value):
            rootView.chartLoadingView.setLoading(false)
            self.history = value
            rootView.chartView.bind(points: value.points, inFiat: inFiat)
            renderPrice()
            updateChangeLabel()
            rootView.chartView.isHidden = value.points.isEmpty
            rootView.chartStatusLabel.text = value.points.isEmpty ? R.string(
                preferredLanguages: selectedLocale.rLanguages
            ).localizable.stakingSubtensorUiDetailHistoryUnavailable() : nil
        case .notListed:
            rootView.chartLoadingView.setLoading(false)
            self.history = nil
            renderPrice()
            updateChangeLabel()
            rootView.chartView.isHidden = true
            rootView.chartStatusLabel.text = R.string(
                preferredLanguages: selectedLocale.rLanguages
            ).localizable.stakingSubtensorUiDetailHistoryUnavailable()
        case .none:
            self.history = nil
            updateChangeLabel()
            rootView.chartLoadingView.setLoading(true)
            rootView.chartView.isHidden = true
            rootView.chartStatusLabel.text = nil
        }
    }

    func didReceive(risk: String?) {
        rootView.riskLabel.text = risk ?? R.string(
            preferredLanguages: selectedLocale.rLanguages
        ).localizable.stakingSubtensorUiDetailRiskUnavailable()
    }

    func didReceiveFavorite(_ isFavorite: Bool) {
        rootView.favoriteButton.setImage(
            isFavorite ? R.image.iconFavToolbarSel() : R.image.iconUnfavorite(),
            for: .normal
        )
        let strings = R.string(preferredLanguages: selectedLocale.rLanguages).localizable
        rootView.favoriteButton.accessibilityLabel = isFavorite
            ? strings.stakingSubtensorUiDetailFavoriteRemove()
            : strings.stakingSubtensorUiDetailFavoriteAdd()
    }
}

extension SubtensorSubnetDetailsViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded { setupLocalization() }
    }
}
