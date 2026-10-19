import Foundation_iOS
import UIKit

final class SubtensorPortfolioViewController: UIViewController, ViewHolder {
    typealias RootViewType = SubtensorPortfolioViewLayout

    let presenter: SubtensorPortfolioPresenterProtocol

    let seekHapticPlayer: ProgressiveHapticPlayer
    let chartLongPressHapticPlayer: HapticPlayer
    private let periodControlHapticPlayer: HapticPlayer

    init(
        presenter: SubtensorPortfolioPresenterProtocol,
        seekHapticPlayer: ProgressiveHapticPlayer,
        chartLongPressHapticPlayer: HapticPlayer,
        periodControlHapticPlayer: HapticPlayer,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.presenter = presenter
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
        view = SubtensorPortfolioViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupHandlers()
        setupLocalization()

        presenter.setup()
    }
}

private extension SubtensorPortfolioViewController {
    func setupHandlers() {
        rootView.addButton.addTarget(self, action: #selector(actionAdd), for: .touchUpInside)
        rootView.syncNoticeView.addGestureRecognizer(
            UITapGestureRecognizer(target: self, action: #selector(actionRetry))
        )
        rootView.headerView.periodControl.addTarget(self, action: #selector(actionPeriod), for: .valueChanged)
        rootView.headerView.chartView.delegate = self
        rootView.containerView.scrollView.refreshControl?.addTarget(
            self,
            action: #selector(actionRefresh),
            for: .valueChanged
        )

        rootView.onSelectPosition = { [weak self] index in
            self?.presenter.selectPosition(at: index)
        }
    }

    func setupLocalization() {
        let strings = R.string(preferredLanguages: selectedLocale.rLanguages).localizable

        title = strings.stakingSubtensorUiPortfolioTitle()

        let ratesUnavailable = strings.stakingSubtensorUiPortfolioRatesUnavailable()

        rootView.headerView.captionLabel.text = strings.stakingSubtensorUiPortfolioTotal()
        rootView.headerView.ratesAlertView.contentView.detailsLabel.text = ratesUnavailable
        rootView.positionsCaptionLabel.applySubtensorCaps(strings.stakingSubtensorUiPortfolioPositions())
        rootView.syncNoticeView.contentView.detailsLabel.text = strings.stakingSubtensorUiPortfolioSyncFailed()

        let emptyView = rootView.emptyView
        emptyView.bind(caption: strings.stakingSubtensorUiPortfolioEmptyCaption())
        emptyView.subnetCardView.bind(title: strings.stakingSubtensorUiPortfolioEmptySubnetTitle())
        emptyView.subnetCardView.bind(subtitle: strings.stakingSubtensorUiPortfolioEmptySubnetSubtitle())
        emptyView.rootCardView.bind(title: strings.stakingSubtensorUiPortfolioEmptyRootTitle())
        emptyView.unstakeCardView.bind(title: strings.stakingSubtensorUiPortfolioEmptyUnstakeTitle())
        emptyView.unstakeCardView.bind(subtitle: strings.stakingSubtensorUiPortfolioEmptyUnstakeSubtitle())

        rootView.addButton.imageWithTitleView?.title = strings.stakingSubtensorUiPortfolioAdd()
        rootView.addButton.invalidateLayout()
    }

    @objc func actionAdd() {
        presenter.addPosition()
    }

    @objc func actionRetry() {
        presenter.retry()
    }

    @objc func actionRefresh() {
        presenter.refresh()
    }

    @objc func actionPeriod() {
        periodControlHapticPlayer.play()
        presenter.selectPeriod(at: rootView.headerView.periodControl.selectedSegmentIndex)
    }
}

extension SubtensorPortfolioViewController: SubtensorPortfolioViewProtocol {
    func didReceive(viewModel: SubtensorPortfolioViewModel) {
        rootView.bind(viewModel: viewModel)
    }

    func didReceive(header: SubtensorPortfolioHeaderViewModel) {
        rootView.headerView.bind(viewModel: header)
    }

    func didCompleteRefreshing() {
        rootView.containerView.scrollView.refreshControl?.endRefreshing()
    }
}

extension SubtensorPortfolioViewController: SubtensorChartHapticsHandling {
    func didSelectChart(_ selection: SubtensorPriceChartSelection?) {
        guard case let .point(sourceIndex) = selection else {
            presenter.selectChartPoint(at: nil)
            return
        }

        presenter.selectChartPoint(at: sourceIndex)
    }
}

extension SubtensorPortfolioViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}
