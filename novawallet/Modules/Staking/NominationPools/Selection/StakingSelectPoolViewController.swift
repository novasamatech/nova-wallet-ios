import UIKit
import Foundation_iOS

typealias StakingSelectPoolViewModel = StakingPoolTableViewCell.Model

final class StakingSelectPoolViewController: UIViewController, ViewHolder {
    typealias RootViewType = StakingSelectPoolViewLayout

    let presenter: StakingSelectPoolPresenterProtocol
    let numberFormatter: LocalizableResource<NumberFormatter>

    private var state: LoadableViewModelState<[StakingSelectPoolViewModel]> = .loading

    init(
        presenter: StakingSelectPoolPresenterProtocol,
        numberFormatter: LocalizableResource<NumberFormatter>,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.presenter = presenter
        self.numberFormatter = numberFormatter
        super.init(nibName: nil, bundle: nil)
        self.localizationManager = localizationManager
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = StakingSelectPoolViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        rootView.tableView.dataSource = self
        rootView.tableView.delegate = self
        setupLocalization()
        setupHandlers()
        navigationItem.rightBarButtonItem = UIBarButtonItem(customView: rootView.searchButton)

        presenter.setup()
    }

    private func setupLocalization() {
        title = R.string(preferredLanguages: selectedLocale.rLanguages).localizable.stakingSelectPoolTitle()

        let buttonTitle = R.string(preferredLanguages: selectedLocale.rLanguages
        ).localizable.stakingSelectValidatorsRecommendedButtonTitle()

        rootView.recommendedButton.imageWithTitleView?.title = buttonTitle
    }

    private func setupHandlers() {
        rootView.recommendedButton.addTarget(self, action: #selector(selectRecommendedAction), for: .touchUpInside)
        rootView.searchButton.addTarget(self, action: #selector(searchAction), for: .touchUpInside)
    }

    @objc private func selectRecommendedAction() {
        presenter.selectRecommended()
    }

    @objc private func searchAction() {
        presenter.search()
    }
}

extension StakingSelectPoolViewController: StakingSelectPoolViewProtocol {
    func didReceivePools(state: LoadableViewModelState<[StakingSelectPoolViewModel]>) {
        self.state = state
        switch state {
        case .loading:
            rootView.loadingView.isHidden = false
            rootView.loadingView.start()
        case .cached, .loaded:
            rootView.loadingView.stop()
            rootView.loadingView.isHidden = true
            rootView.tableView.reloadData()
        }
    }

    func didReceivePoolUpdate(viewModel: StakingSelectPoolViewModel) {
        guard let viewModels = state.value,
              let index = viewModels.firstIndex(where: { $0.id == viewModel.id }) else {
            return
        }

        state.insert(newElement: viewModel, at: index)

        if let cell = rootView.tableView.visibleCells[safe: index] as? StakingPoolTableViewCell {
            cell.bind(viewModel: viewModel)
        }
    }

    func didReceiveRecommendedButton(viewModel: ButtonViewModel) {
        switch viewModel {
        case .hidden:
            rootView.recommendedButton.isHidden = true
        case .active:
            rootView.recommendedButton.isHidden = false
            rootView.recommendedButton.isUserInteractionEnabled = true
            rootView.recommendedButton.apply(style: .accentButton)
        case .inactive:
            rootView.recommendedButton.isHidden = false
            rootView.recommendedButton.isUserInteractionEnabled = false
            rootView.recommendedButton.apply(style: .inactiveButton)
        }
    }
}

extension StakingSelectPoolViewController: UITableViewDataSource {
    func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
        state.value?.count ?? 0
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell: StakingPoolTableViewCell = tableView.dequeueReusableCell(for: indexPath)
        if let model = state.value?[safe: indexPath.row] {
            cell.bind(viewModel: model)
            cell.infoAction = { [weak self] viewModel in
                self?.presenter.showPoolInfo(poolId: viewModel.id)
            }
        }
        return cell
    }
}

extension StakingSelectPoolViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard let model = state.value?[safe: indexPath.row] else {
            return
        }
        presenter.selectPool(poolId: model.id)
    }

    func tableView(_: UITableView, heightForRowAt _: IndexPath) -> CGFloat {
        44
    }

    func tableView(_: UITableView, heightForHeaderInSection _: Int) -> CGFloat {
        guard let viewModels = state.value, !viewModels.isEmpty else {
            return 0
        }
        return 26
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection _: Int) -> UIView? {
        guard let viewModels = state.value, !viewModels.isEmpty else {
            return nil
        }
        let header: StakingSelectPoolListHeaderView = tableView.dequeueReusableHeaderFooterView()
        let title = R.string(preferredLanguages: selectedLocale.rLanguages
        ).localizable.stakingSelectPoolCount(viewModels.count)
        let details = R.string(preferredLanguages: selectedLocale.rLanguages).localizable.stakingSelectPoolMembers()
        header.bind(
            title: title,
            details: details
        )
        return header
    }
}

extension StakingSelectPoolViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            rootView.tableView.reloadData()
            setupLocalization()
        }
    }
}
