import UIKit
import Foundation_iOS
import UIKit_iOS

final class StakingRewardPayoutsViewController: UIViewController, ViewHolder {
    typealias RootViewType = StakingRewardPayoutsViewLayout

    // MARK: Properties -

    let presenter: StakingRewardPayoutsPresenterProtocol
    private let localizationManager: LocalizationManagerProtocol?
    private var viewState: StakingRewardPayoutsViewState?
    private let countdownTimer: CountdownTimerProtocol
    private var eraCompletionTime: TimeInterval?

    var selectedLocale: Locale {
        localizationManager?.selectedLocale ?? .autoupdatingCurrent
    }

    // MARK: Init -

    init(
        presenter: StakingRewardPayoutsPresenterProtocol,
        localizationManager: LocalizationManagerProtocol?,
        countdownTimer: CountdownTimerProtocol
    ) {
        self.presenter = presenter
        self.localizationManager = localizationManager
        self.countdownTimer = countdownTimer
        super.init(nibName: nil, bundle: nil)
        self.countdownTimer.delegate = self
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        countdownTimer.stop()
    }

    // MARK: Lifecycle -

    override func loadView() {
        view = StakingRewardPayoutsViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupLocalization()
        setupTable()
        setupPayoutButtonAction()
        presenter.setup()
    }

    private func setupTitleLocalization() {
        title = R.string.localizable.stakingRewardPayoutsTitle_v2_2_0(
            preferredLanguages: selectedLocale.rLanguages
        )
    }

    private func setupButtonLocalization() {
        rootView.payoutButton.imageWithTitleView?.title = R.string.localizable.stakingPendingRewardsPayoutAll(
            preferredLanguages: selectedLocale.rLanguages
        )
    }

    private func setupTable() {
        rootView.tableView.registerClassesForCell(
            [
                StakingRewardHistoryTableCell.self,
                StakingRewardsHeaderCell.self
            ]
        )

        rootView.tableView.delegate = self
        rootView.tableView.dataSource = self
    }

    private func setupPayoutButtonAction() {
        rootView.payoutButton.addTarget(
            self,
            action: #selector(handlePayoutButtonAction),
            for: .touchUpInside
        )
    }

    @objc
    private func handlePayoutButtonAction() {
        presenter.handlePayoutAction()
    }
}

extension StakingRewardPayoutsViewController: StakingRewardPayoutsViewProtocol {
    func reload(with state: StakingRewardPayoutsViewState) {
        viewState = state
        countdownTimer.stop()

        switch state {
        case .loading:
            rootView.payoutButton.isHidden = true
            rootView.tableView.reloadData()
        case let .payoutsList(viewModel):
            rootView.payoutButton.isHidden = false

            let localizedViewModel = viewModel.value(for: selectedLocale)
            if let time = localizedViewModel.eraComletionTime {
                countdownTimer.start(with: time, runLoop: .main, mode: .common)
            }

            rootView.tableView.reloadData()
        case .emptyList, .error:
            rootView.payoutButton.isHidden = true
            rootView.tableView.reloadData()
        }
        reloadEmptyState(animated: true)
    }
}

extension StakingRewardPayoutsViewController: Localizable {
    private func setupLocalization() {
        setupTitleLocalization()
        setupButtonLocalization()
    }

    func applyLocalization() {
        if isViewLoaded {
            reloadEmptyState(animated: false)
            setupLocalization()
            rootView.tableView.reloadData()
            view.setNeedsLayout()
        }
    }
}

extension StakingRewardPayoutsViewController: UITableViewDelegate {
    func numberOfSections(in _: UITableView) -> Int {
        guard let state = viewState,
              case StakingRewardPayoutsViewState.payoutsList = state
        else { return 1 }
        return 2
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        guard indexPath.section == 1 else { return }
        presenter.handleSelectedHistory(at: indexPath.row)
    }
}

extension StakingRewardPayoutsViewController: UITableViewDataSource {
    func tableView(_: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let state = viewState else { return 1 }
        if case let StakingRewardPayoutsViewState.payoutsList(viewModel) = state {
            return section == 0 ? 1 : viewModel.value(for: selectedLocale).cellViewModels.count
        }
        return 1
    }

    func tableView(_: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard
            let state = viewState,
            case let StakingRewardPayoutsViewState.payoutsList(viewModel) = state,
            indexPath.section > 0
        else {
            let titleCell = rootView.tableView.dequeueReusableCellWithType(StakingRewardsHeaderCell.self)!
            titleCell.locale = selectedLocale
            return titleCell
        }

        let cell = rootView.tableView.dequeueReusableCellWithType(
            StakingRewardHistoryTableCell.self)!
        let model = viewModel.value(for: selectedLocale).cellViewModels[indexPath.row]
        cell.bind(model: model)
        return cell
    }
}

extension StakingRewardPayoutsViewController: EmptyStateViewOwnerProtocol {
    var emptyStateDelegate: EmptyStateDelegate { self }
    var emptyStateDataSource: EmptyStateDataSource { self }
}

extension StakingRewardPayoutsViewController: EmptyStateDataSource {
    var viewForEmptyState: UIView? {
        guard let state = viewState else { return nil }

        switch state {
        case let .error(error):
            let errorView = ErrorStateView()
            errorView.errorDescriptionLabel.text = error.value(for: selectedLocale)
            errorView.delegate = self
            errorView.locale = selectedLocale
            return errorView
        case .emptyList:
            let emptyView = EmptyStateView()
            emptyView.image = R.image.iconSearchHappy()!
            emptyView.title = R.string.localizable.stakingRewardPayoutsEmptyRewards_2_2_0(
                preferredLanguages: selectedLocale.rLanguages
            )
            emptyView.titleColor = R.color.colorTextSecondary()!
            emptyView.titleFont = .regularFootnote
            return emptyView
        case .loading:
            let loadingView = ListLoadingView()
            loadingView.titleLabel.text = R.string.localizable.stakingPendingRewardSearch(
                preferredLanguages: selectedLocale.rLanguages
            )
            loadingView.start()
            return loadingView
        case .payoutsList:
            return nil
        }
    }
}

extension StakingRewardPayoutsViewController: EmptyStateDelegate {
    var shouldDisplayEmptyState: Bool {
        guard let state = viewState else { return false }
        switch state {
        case .error, .emptyList, .loading:
            return true
        case .payoutsList:
            return false
        }
    }
}

extension StakingRewardPayoutsViewController: ErrorStateViewDelegate {
    func didRetry(errorView _: ErrorStateView) {
        presenter.reload()
    }
}

extension StakingRewardPayoutsViewController: CountdownTimerDelegate {
    func updateView() {
        let visiblePayoutCells = rootView.tableView.visibleCells.compactMap { cell in
            cell as? StakingRewardHistoryTableCell
        }

        visiblePayoutCells.forEach { cell in
            guard let indexPath = rootView.tableView.indexPath(for: cell) else {
                return
            }

            guard let timeLeftText = presenter.getTimeLeftString(at: indexPath.row) else {
                return
            }

            cell.bind(timeLeftText: timeLeftText.value(for: selectedLocale))
        }
    }

    func didStart(with remainedInterval: TimeInterval) {
        eraCompletionTime = remainedInterval
        updateView()
    }

    func didCountdown(remainedInterval: TimeInterval) {
        eraCompletionTime = remainedInterval
        updateView()
    }

    func didStop(with _: TimeInterval) {
        eraCompletionTime = 0
        updateView()
    }
}
