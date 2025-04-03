import UIKit
import Foundation_iOS

final class HardwareWalletAddressesViewController: UIViewController, ViewHolder {
    typealias RootViewType = HardwareWalletAddressesViewLayout

    let presenter: HardwareWalletAddressesPresenterProtocol

    private var viewModels: [ChainAccountViewModelItem] = []

    init(
        presenter: HardwareWalletAddressesPresenterProtocol,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.presenter = presenter

        super.init(nibName: nil, bundle: nil)

        self.localizationManager = localizationManager
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = HardwareWalletAddressesViewLayout()
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
        rootView.actionButton.imageWithTitleView?.title = R.string.localizable.commonContinue(
            preferredLanguages: languages
        )
    }

    @objc private func actionProceed() {
        presenter.proceed()
    }
}

// MARK: - UITableViewDataSource

extension HardwareWalletAddressesViewController: UITableViewDataSource {
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

extension HardwareWalletAddressesViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        presenter.select(viewModel: viewModels[indexPath.row])
    }
}

extension HardwareWalletAddressesViewController: HardwareWalletAddressesViewProtocol {
    func didReceive(viewModels: [ChainAccountViewModelItem]) {
        self.viewModels = viewModels

        rootView.tableView.reloadData()
    }

    func didReceive(descriptionViewModel: TitleWithSubtitleViewModel) {
        if descriptionViewModel.subtitle.isEmpty {
            rootView.headerView.bind(topValue: descriptionViewModel.title, bottomValue: nil)
        } else {
            rootView.headerView.bind(
                topValue: descriptionViewModel.title,
                bottomValue: descriptionViewModel.subtitle
            )
        }

        rootView.setNeedsLayout()
    }
}

extension HardwareWalletAddressesViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}
