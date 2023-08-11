import UIKit
import SoraFoundation

typealias StakingSelectPoolViewModel = StakingPoolTableViewCell.Model

final class StakingSelectPoolViewController: UIViewController, ViewHolder {
    typealias RootViewType = StakingSelectPoolViewLayout
    private var pools: [StakingSelectPoolViewModel] = []
    let presenter: StakingSelectPoolPresenterProtocol
    let numberFormatter: LocalizableResource<NumberFormatter>

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
        setupTitle()

        presenter.setup()
    }

    private func setupTitle() {
        title = R.string.localizable.stakingSelectPoolTitle(preferredLanguages: selectedLocale.rLanguages)
    }
}

extension StakingSelectPoolViewController: StakingSelectPoolViewProtocol {
    func didReceivePools(viewModels: [StakingSelectPoolViewModel]) {
        pools = viewModels
        rootView.tableView.reloadData()
    }

    func didReceivePoolUpdate(viewModel: StakingSelectPoolViewModel) {
        guard let index = pools.firstIndex(where: { $0.id == viewModel.id }) else {
            return
        }
        pools[index] = viewModel

        if let cell = rootView.tableView.visibleCells[safe: index] as? StakingPoolTableViewCell {
            cell.bind(viewModel: viewModel)
        }
    }
}

extension StakingSelectPoolViewController: UITableViewDataSource {
    func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
        pools.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell: StakingPoolTableViewCell = tableView.dequeueReusableCell(for: indexPath)
        if let model = pools[safe: indexPath.row] {
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
        guard let model = pools[safe: indexPath.row] else {
            return
        }
        presenter.selectPool(poolId: model.id)
    }

    func tableView(_: UITableView, heightForRowAt _: IndexPath) -> CGFloat {
        44
    }

    func tableView(_: UITableView, heightForHeaderInSection _: Int) -> CGFloat {
        26
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection _: Int) -> UIView? {
        let header: StakingSelectPoolListHeaderView = tableView.dequeueReusableHeaderFooterView()
        let count = numberFormatter.value(for: selectedLocale).string(from: NSNumber(value: pools.count))
        let title = R.string.localizable.stakingSelectPoolCount(
            count ?? "",
            preferredLanguages: selectedLocale.rLanguages
        )
        let details = R.string.localizable.stakingSelectPoolMembers(preferredLanguages: selectedLocale.rLanguages)
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
            setupTitle()
        }
    }
}
