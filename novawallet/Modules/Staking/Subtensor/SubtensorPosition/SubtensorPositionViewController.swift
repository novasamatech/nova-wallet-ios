import Foundation_iOS
import UIKit

final class SubtensorPositionViewController: UIViewController, ViewHolder {
    typealias RootViewType = SubtensorPositionViewLayout

    let presenter: SubtensorPositionPresenterProtocol
    let isRoot: Bool

    let seekHapticPlayer: ProgressiveHapticPlayer
    let chartLongPressHapticPlayer: HapticPlayer
    private let periodControlHapticPlayer: HapticPlayer

    init(
        presenter: SubtensorPositionPresenterProtocol,
        isRoot: Bool,
        seekHapticPlayer: ProgressiveHapticPlayer,
        chartLongPressHapticPlayer: HapticPlayer,
        periodControlHapticPlayer: HapticPlayer,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.presenter = presenter
        self.isRoot = isRoot
        self.seekHapticPlayer = seekHapticPlayer
        self.chartLongPressHapticPlayer = chartLongPressHapticPlayer
        self.periodControlHapticPlayer = periodControlHapticPlayer

        super.init(nibName: nil, bundle: nil)

        self.localizationManager = localizationManager
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = SubtensorPositionViewLayout(isRoot: isRoot)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupHandlers()

        presenter.setup()
    }
}

private extension SubtensorPositionViewController {
    func setupHandlers() {
        rootView.onSelectAction = { [weak self] action in
            self?.presenter.selectAction(action)
        }

        rootView.sellButton.addTarget(self, action: #selector(actionSell), for: .touchUpInside)
        rootView.buyButton.addTarget(self, action: #selector(actionBuy), for: .touchUpInside)
        rootView.validatorView.addTarget(self, action: #selector(actionValidator), for: .touchUpInside)
        rootView.periodControl.addTarget(self, action: #selector(actionPeriod), for: .valueChanged)
        rootView.chartUnavailableView.addTarget(self, action: #selector(actionRetryHistory), for: .touchUpInside)
        rootView.chartView.delegate = self
        rootView.syncNoticeView.addGestureRecognizer(
            UITapGestureRecognizer(target: self, action: #selector(actionRetrySync))
        )
    }

    @objc func actionSell() {
        presenter.selectAction(.sell)
    }

    @objc func actionBuy() {
        presenter.selectAction(.buy)
    }

    @objc func actionValidator() {
        presenter.selectValidator()
    }

    @objc func actionPeriod() {
        periodControlHapticPlayer.play()
        presenter.selectPeriod(at: rootView.periodControl.selectedSegmentIndex)
    }

    @objc func actionRetryHistory() {
        presenter.retryHistory()
    }

    @objc func actionRetrySync() {
        presenter.retrySync()
    }
}

extension SubtensorPositionViewController: SubtensorPositionViewProtocol {
    func didReceive(viewModel: SubtensorPositionViewModel) {
        title = viewModel.title
        rootView.bind(viewModel: viewModel, locale: selectedLocale)
    }

    func didReceive(priceHeader: SubtensorSubnetPriceHeaderViewModel) {
        rootView.priceWidget.bind(header: priceHeader)
    }
}

extension SubtensorPositionViewController: SubtensorChartHapticsHandling {
    func didSelectChart(_ selection: SubtensorPriceChartSelection?) {
        presenter.selectChart(selection)
    }
}

extension SubtensorPositionViewController: Localizable {
    func applyLocalization() {}
}
