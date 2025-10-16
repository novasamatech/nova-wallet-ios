import UIKit
import Foundation_iOS

class StaticValidatorListViewController: UIViewController, ViewHolder {
    typealias RootViewType = StaticValidatorListViewLayout

    let presenter: StaticValidatorListPresenterProtocol
    let selectedValidatorsLimit: Int

    private var viewModel: SelectedValidatorListViewModel?

    // MARK: - Lifecycle

    init(
        presenter: StaticValidatorListPresenterProtocol,
        selectedValidatorsLimit: Int,
        localizationManager: LocalizationManagerProtocol? = nil
    ) {
        self.presenter = presenter
        self.selectedValidatorsLimit = selectedValidatorsLimit

        super.init(nibName: nil, bundle: nil)

        self.localizationManager = localizationManager
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = StaticValidatorListViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupTable()

        applyLocalization()

        presenter.setup()
    }

    // MARK: - Private functions

    private func setupTable() {
        rootView.tableView.dataSource = self
        rootView.tableView.delegate = self
        rootView.tableView.registerClassForCell(SelectedValidatorCell.self)
        rootView.tableView.registerHeaderFooterView(withClass: SelectedValidatorListHeaderView.self)
    }

    private func updateHeaderView() {
        guard let viewModel = viewModel,
              let headerView = rootView.tableView
              .headerView(forSection: 0) as? SelectedValidatorListHeaderView
        else { return }

        headerView.bind(
            viewModel: viewModel.headerViewModel,
            shouldAlert: viewModel.limitIsExceeded
        )
    }

    private func presentValidatorInfo(at index: Int) {
        presenter.didSelectValidator(at: index)
    }
}

// MARK: - Localizable

extension StaticValidatorListViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            title = R.string(
                preferredLanguages: selectedLocale.rLanguages
            ).localizable.stakingSelectedValidatorsTitle()

            updateHeaderView()
        }
    }
}

// MARK: - SelectedValidatorListViewProtocol

extension StaticValidatorListViewController: StaticValidatorListViewProtocol {
    func didReload(_ viewModel: SelectedValidatorListViewModel) {
        self.viewModel = viewModel
        rootView.tableView.reloadData()
    }
}

// MARK: - UITableViewDataSource

extension StaticValidatorListViewController: UITableViewDataSource {
    func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
        viewModel?.cellViewModels.count ?? 0
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let viewModel = viewModel else {
            return UITableViewCell()
        }

        let cell = tableView.dequeueReusableCellWithType(SelectedValidatorCell.self)!

        let cellViewModel = viewModel.cellViewModels[indexPath.row]
        cell.bind(viewModel: cellViewModel)

        return cell
    }
}

// MARK: - UITableViewDelegate

extension StaticValidatorListViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        presenter.didSelectValidator(at: indexPath.row)
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection _: Int) -> UIView? {
        guard let viewModel = viewModel else { return nil }

        let headerView: SelectedValidatorListHeaderView = tableView.dequeueReusableHeaderFooterView()
        headerView.bind(
            viewModel: viewModel.headerViewModel,
            shouldAlert: viewModel.limitIsExceeded
        )

        return headerView
    }
}
