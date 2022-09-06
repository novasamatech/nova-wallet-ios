import UIKit
import SoraFoundation

final class LedgerNetworkSelectionViewController: UIViewController, ViewHolder {
    typealias RootViewType = LedgerNetworkSelectionViewLayout

    let presenter: LedgerNetworkSelectionPresenterProtocol

    private var viewModels: [ChainAccountAddViewModel] = []

    init(presenter: LedgerNetworkSelectionPresenterProtocol, localizationManager: LocalizationManagerProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)

        self.localizationManager = localizationManager
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = LedgerNetworkSelectionViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupTableView()
        setupHandlers()
        setupLocalization()
        updateActionButton()

        presenter.setup()
    }

    private func setupLocalization() {
        let languages = selectedLocale.rLanguages

        rootView.headerView.valueTop.text = R.string.localizable.ledgerAccountsTitle(preferredLanguages: languages)
        rootView.headerView.valueBottom.text = R.string.localizable.ledgerAccountsSubtitle(
            preferredLanguages: languages
        )

        updateActionButton()
    }

    private func setupTableView() {
        rootView.tableView.registerClassForCell(ChainAccountAddTableViewCell.self)
        rootView.tableView.rowHeight = 52.0
        rootView.tableView.delegate = self
        rootView.tableView.dataSource = self
    }

    private func updateActionButton() {
        let hasAccount = viewModels.contains { $0.exists }

        if hasAccount {
            rootView.actionButton.applyEnabledStyle()
            rootView.actionButton.isUserInteractionEnabled = true

            rootView.actionButton.imageWithTitleView?.title = R.string.localizable.commonDone(
                preferredLanguages: selectedLocale.rLanguages
            )
        } else {
            rootView.actionButton.applyDisabledStyle()
            rootView.actionButton.isUserInteractionEnabled = false

            rootView.actionButton.imageWithTitleView?.title = R.string.localizable.ledgerAccountsButtonAdd(
                preferredLanguages: selectedLocale.rLanguages
            )
        }

        rootView.actionButton.invalidateLayout()
    }

    private func setupHandlers() {
        navigationItem.leftBarButtonItem = rootView.backButton

        rootView.backButton.target = self
        rootView.backButton.action = #selector(actionCancel)

        rootView.actionButton.addTarget(self, action: #selector(actionProceed), for: .touchUpInside)
    }

    @objc private func actionCancel() {
        presenter.cancel()
    }

    @objc private func actionProceed() {
        presenter.proceed()
    }
}

// MARK: - UITableViewDataSource

extension LedgerNetworkSelectionViewController: UITableViewDataSource {
    func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
        viewModels.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithType(ChainAccountAddTableViewCell.self)!

        let viewModel = viewModels[indexPath.row]

        cell.bind(viewModel: viewModel)

        if viewModel.exists {
            cell.selectionStyle = .none
        } else {
            cell.selectionStyle = .default
        }

        return cell
    }
}

// MARK: - UITableViewDelegate

extension LedgerNetworkSelectionViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        presenter.selectChainAccount(at: indexPath.row)
    }
}

extension LedgerNetworkSelectionViewController: LedgerNetworkSelectionViewProtocol {
    func didReceive(viewModels: [ChainAccountAddViewModel]) {
        self.viewModels = viewModels

        rootView.tableView.reloadData()

        updateActionButton()
    }
}

extension LedgerNetworkSelectionViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}
