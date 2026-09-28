import Foundation_iOS
import UIKit

final class SubtensorPortfolioViewController: UIViewController, ViewHolder {
    typealias RootViewType = SubtensorPortfolioViewLayout

    let presenter: SubtensorPortfolioPresenterProtocol
    private var selectedPeriodTitle = "30D"

    init(
        presenter: SubtensorPortfolioPresenterProtocol,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
        self.localizationManager = localizationManager
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func loadView() { view = SubtensorPortfolioViewLayout() }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupLocalization()
        rootView.addButton.addTarget(self, action: #selector(actionAdd), for: .touchUpInside)
        rootView.syncNoticeButton.addTarget(self, action: #selector(actionRetry), for: .touchUpInside)
        rootView.periodButtons[2].backgroundColor = R.color.colorContainerBackground()
        for (index, button) in rootView.periodButtons.enumerated() {
            button.tag = index
            button.addTarget(self, action: #selector(actionPeriod(_:)), for: .touchUpInside)
        }
        presenter.setup()
    }

    @objc private func actionAdd() { presenter.addPosition() }
    @objc private func actionRetry() { presenter.retry() }

    @objc private func actionPeriod(_ sender: UIButton) {
        let periods: [SubtensorPricePeriod] = [.day, .week, .month, .year, .all]
        rootView.periodButtons.forEach { $0.backgroundColor = .clear }
        sender.backgroundColor = R.color.colorContainerBackground()
        selectedPeriodTitle = sender.title(for: .normal) ?? selectedPeriodTitle
        presenter.selectPeriod(periods[sender.tag])
    }

    private func setupLocalization() {
        let strings = R.string(preferredLanguages: selectedLocale.rLanguages).localizable
        title = strings.stakingSubtensorUiPortfolioTitle()
        rootView.totalCaption.text = strings.stakingSubtensorUiPortfolioTotal()
        rootView.positionsCaption.text = strings.stakingSubtensorUiPortfolioPositions()
        rootView.emptyLabel.text = strings.stakingSubtensorUiPortfolioEmpty()
        rootView.syncNoticeButton.setTitle(strings.stakingSubtensorUiPortfolioSyncFailed(), for: .normal)
        rootView.addButton.imageWithTitleView?.title = strings.stakingSubtensorUiPortfolioAdd()
        rootView.addButton.invalidateLayout()
    }
}

extension SubtensorPortfolioViewController: SubtensorPortfolioViewProtocol {
    func didReceive(viewModel: SubtensorPortfolioViewModel) {
        rootView.totalLabel.text = viewModel.total
        let currency = CurrencyManager.shared?.selectedCurrency
        rootView.fiatLabel.text = viewModel.fiat.map {
            "≈ \(currency?.symbol ?? currency?.code ?? "")\($0)"
        }
        rootView.bind(rows: viewModel.rows) { [weak self] index in
            self?.presenter.selectPosition(at: index)
        }
        rootView.syncNoticeButton.isHidden = !viewModel.syncFailed
    }

    func didReceiveChartLoading() {
        rootView.chartView.isHidden = true
        rootView.chartStatusLabel.text = nil
        rootView.chartLoadingView.setLoading(true)
    }

    func didReceive(series: SubtensorPortfolioValueSeries?) {
        rootView.chartLoadingView.setLoading(false)
        guard let series, series.points.count > 1 else {
            rootView.chartView.isHidden = true
            let strings = R.string(preferredLanguages: selectedLocale.rLanguages).localizable
            rootView.chartStatusLabel.text = strings.stakingSubtensorUiChartUnavailable()
            rootView.chartNoteLabel.text = strings.stakingSubtensorUiChartHistoryUnavailable()
            rootView.changeLabel.text = nil
            return
        }

        rootView.chartView.bind(values: series.points.map { NSDecimalNumber(decimal: $0.fiatValue).doubleValue })
        rootView.chartView.isHidden = false
        rootView.chartStatusLabel.text = nil
        let strings = R.string(preferredLanguages: selectedLocale.rLanguages).localizable
        rootView.chartNoteLabel.text = series.netuidsWithoutHistory.isEmpty
            ? nil : strings.stakingSubtensorUiChartPartial()
        if let change = series.changeInFiat {
            let percent = NSDecimalNumber(decimal: change * 100).doubleValue
            rootView.changeLabel.text = String(format: "%+.1f%% · %@", percent, selectedPeriodTitle)
            rootView.changeLabel.textColor = change < 0 ? R.color.colorTextNegative() : R.color.colorTextPositive()
        } else {
            rootView.changeLabel.text = nil
        }
    }
}

extension SubtensorPortfolioViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded { setupLocalization() }
    }
}
