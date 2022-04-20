import UIKit
import SoraFoundation
import SoraUI

final class DAppAuthSettingsViewController: UIViewController, ViewHolder {
    enum Row {
        case wallet
        case authorized(index: Int)

        init(indexPath: IndexPath) {
            if indexPath.row == 0 {
                self = .wallet
            } else {
                self = .authorized(index: indexPath.row - 1)
            }
        }
    }

    typealias RootViewType = DAppAuthSettingsViewLayout

    let presenter: DAppAuthSettingsPresenterProtocol

    private var walletViewModel: DisplayWalletViewModel?
    private var authorizedViewModels: [DAppAuthSettingsViewModel]?

    init(presenter: DAppAuthSettingsPresenterProtocol, localizationManager: LocalizationManagerProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)

        self.localizationManager = localizationManager
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = DAppAuthSettingsViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupLocalization()
        setupTableView()

        presenter.setup()
    }

    private func setupTableView() {
        rootView.tableView.registerClassesForCell([
            DAppsAuthSettingsWalletCell.self,
            DAppAuthSettingsTableCell.self
        ])

        rootView.tableView.dataSource = self
    }

    private func setupLocalization() {
        title = R.string.localizable.dappAuthorizedTitle(preferredLanguages: selectedLocale.rLanguages)
    }
}

extension DAppAuthSettingsViewController: UITableViewDataSource {
    private func createWalletCell(_ tableView: UITableView, indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithType(
            DAppsAuthSettingsWalletCell.self,
            forIndexPath: indexPath
        )

        cell.locale = selectedLocale

        if let viewModel = walletViewModel {
            cell.bind(viewModel: viewModel)
        }

        return cell
    }

    private func createAuthorizedCell(
        _ tableView: UITableView,
        indexPath: IndexPath,
        viewModel: DAppAuthSettingsViewModel
    ) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithType(
            DAppAuthSettingsTableCell.self,
            forIndexPath: indexPath
        )

        cell.delegate = self

        cell.bind(viewModel: viewModel)

        return cell
    }

    func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
        (authorizedViewModels?.count ?? 0) + 1
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch Row(indexPath: indexPath) {
        case .wallet:
            return createWalletCell(tableView, indexPath: indexPath)
        case let .authorized(index):
            if let viewModel = authorizedViewModels?[index] {
                return createAuthorizedCell(tableView, indexPath: indexPath, viewModel: viewModel)
            } else {
                return UITableViewCell()
            }
        }
    }
}

extension DAppAuthSettingsViewController: DAppAuthSettingsViewProtocol {
    func didReceiveWallet(viewModel: DisplayWalletViewModel) {
        walletViewModel = viewModel

        rootView.tableView.reloadData()
    }

    func didReceiveAuthorized(viewModels: [DAppAuthSettingsViewModel]) {
        authorizedViewModels = viewModels

        rootView.tableView.reloadData()
        reloadEmptyState(animated: false)
    }
}

extension DAppAuthSettingsViewController: EmptyStateViewOwnerProtocol {
    var emptyStateDelegate: EmptyStateDelegate { self }
    var emptyStateDataSource: EmptyStateDataSource { self }
    var contentViewForEmptyState: UIView { rootView }
}

extension DAppAuthSettingsViewController: EmptyStateDataSource {
    var viewForEmptyState: UIView? {
        let emptyView = EmptyStateView()
        emptyView.image = R.image.iconEmptyHistory()
        emptyView.title = R.string.localizable.dappAuthorizedEmpty(
            preferredLanguages: selectedLocale.rLanguages
        )
        emptyView.titleColor = R.color.colorTransparentText()!
        emptyView.titleFont = .regularFootnote
        return emptyView
    }
}

extension DAppAuthSettingsViewController: EmptyStateDelegate {
    var shouldDisplayEmptyState: Bool {
        guard let authorizedViewModels = authorizedViewModels else {
            return false
        }

        return authorizedViewModels.isEmpty
    }

    var displayInsetsForEmptyState: UIEdgeInsets {
        UIEdgeInsets(top: 110.0, left: 0, bottom: 0, right: 0)
    }
}

extension DAppAuthSettingsViewController: DAppAuthSettingsTableCellDelegate {
    func authSettingsDidSelectCell(_ cell: DAppAuthSettingsTableCell) {
        guard
            let indexPath = rootView.tableView.indexPath(for: cell),
            case let .authorized(index) = Row(indexPath: indexPath),
            let viewModel = authorizedViewModels?[index] else {
            return
        }

        presenter.remove(viewModel: viewModel)
    }
}

extension DAppAuthSettingsViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()

            rootView.tableView.reloadData()
            reloadEmptyState(animated: false)
        }
    }
}
