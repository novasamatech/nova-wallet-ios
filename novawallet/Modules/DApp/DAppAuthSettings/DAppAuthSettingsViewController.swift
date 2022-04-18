import UIKit
import SoraFoundation

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

        return cell
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
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
        self.walletViewModel = viewModel

        rootView.tableView.reloadData()
    }

    func didReceiveAuthorized(viewModels: [DAppAuthSettingsViewModel]) {
        self.authorizedViewModels = viewModels

        rootView.tableView.reloadData()
    }
}

extension DAppAuthSettingsViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()

            rootView.tableView.reloadData()
        }
    }
}
