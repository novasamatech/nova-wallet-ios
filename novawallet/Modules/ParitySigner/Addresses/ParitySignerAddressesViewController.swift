import UIKit
import SoraFoundation

final class ParitySignerAddressesViewController: UIViewController, ViewHolder {
    typealias RootViewType = ParitySignerAddressesViewLayout

    let presenter: ParitySignerAddressesPresenterProtocol

    private var viewModels: [ChainAccountViewModelItem] = []

    init(presenter: ParitySignerAddressesPresenterProtocol, localizationManager: LocalizationManagerProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)

        self.localizationManager = localizationManager
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = ParitySignerAddressesViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupTableView()
        setupLocalization()
        setupHandlers()

        presenter.setup()
    }

    private func setupHandlers() {
        rootView.actionButton.addTarget(self, action: #selector(actionProceed), for: .touchUpInside)
    }

    private func setupTableView() {
        rootView.tableView.register(R.nib.accountTableViewCell)
        rootView.tableView.rowHeight = 48.0

        rootView.tableView.dataSource = self
        rootView.tableView.delegate = self
    }

    private func setupLocalization() {
        let languages = selectedLocale.rLanguages
        rootView.titleLabel.text = R.string.localizable.paritySignerAddressesTitle(preferredLanguages: languages)
        rootView.subtitleLabel.text = R.string.localizable.paritySignerAddressesSubtitle(preferredLanguages: languages)

        rootView.actionButton.imageWithTitleView?.title = R.string.localizable.commonContinue(
            preferredLanguages: languages
        )

        rootView.setNeedsLayout()
    }

    @objc private func actionProceed() {
        presenter.proceed()
    }
}

// MARK: - UITableViewDataSource

extension ParitySignerAddressesViewController: UITableViewDataSource {
    func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
        viewModels.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(
            withIdentifier: R.reuseIdentifier.accountCellId,
            for: indexPath
        )!

        cell.setAccessoryActionEnabled(false)

        cell.bind(viewModel: viewModels[indexPath.row])

        return cell
    }
}

// MARK: - UITableViewDelegate

extension ParitySignerAddressesViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        presenter.select(viewModel: viewModels[indexPath.row])
    }
}

extension ParitySignerAddressesViewController: ParitySignerAddressesViewProtocol {
    func didReceive(viewModels: [ChainAccountViewModelItem]) {
        self.viewModels = viewModels

        rootView.tableView.reloadData()
    }
}

extension ParitySignerAddressesViewController {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}
