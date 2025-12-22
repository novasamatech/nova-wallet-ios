import UIKit
import Foundation_iOS

final class HardwareWalletAddressesViewController: UIViewController, ViewHolder {
    typealias RootViewType = HardwareWalletAddressesViewLayout

    let presenter: HardwareWalletAddressesPresenterProtocol

    private var viewModel: HardwareWalletAddressesViewModel = .init(sections: [])

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
}

private extension HardwareWalletAddressesViewController {
    func setupHandlers() {
        rootView.actionButton.addTarget(self, action: #selector(actionProceed), for: .touchUpInside)
    }

    func setupTableView() {
        rootView.tableView.register(R.nib.accountTableViewCell)
        rootView.tableView.registerHeaderFooterView(withClass: IconTitleHeaderView.self)
        rootView.tableView.rowHeight = Constants.cellHeight

        rootView.tableView.dataSource = self
        rootView.tableView.delegate = self
    }

    func setupLocalization() {
        let languages = selectedLocale.rLanguages
        rootView.actionButton.imageWithTitleView?.title = R.string(
            preferredLanguages: languages
        ).localizable.commonContinue()
    }

    @objc func actionProceed() {
        presenter.proceed()
    }

    func getSectionTitle(
        for scheme: HardwareWalletAddressScheme,
        locale: Locale
    ) -> String {
        switch scheme {
        case .substrate:
            R.string(preferredLanguages: locale.rLanguages).localizable.accountsSubstrate().uppercased()
        case .evm:
            R.string(preferredLanguages: locale.rLanguages).localizable.accountsEvm().uppercased()
        }
    }

    func shouldDisplaySectionTitles() -> Bool {
        viewModel.sections.count > 1
    }
}

// MARK: - UITableViewDataSource

extension HardwareWalletAddressesViewController: UITableViewDataSource {
    func numberOfSections(in _: UITableView) -> Int {
        viewModel.sections.count
    }

    func tableView(_: UITableView, numberOfRowsInSection section: Int) -> Int {
        viewModel.sections[section].items.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(
            withIdentifier: R.reuseIdentifier.accountCellId,
            for: indexPath
        )!

        cell.setAccessoryActionEnabled(false)

        let item = viewModel.sections[indexPath.section].items[indexPath.row]

        cell.bind(viewModel: item)

        return cell
    }
}

// MARK: - UITableViewDelegate

extension HardwareWalletAddressesViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard shouldDisplaySectionTitles() else {
            return nil
        }

        let headerView: IconTitleHeaderView = tableView.dequeueReusableHeaderFooterView()
        headerView.titleView.detailsLabel.apply(style: .semiboldCaps2Secondary)
        headerView.backgroundView?.backgroundColor = R.color.colorSecondaryScreenBackground()

        let title = getSectionTitle(for: viewModel.sections[section].scheme, locale: selectedLocale)
        headerView.titleView.bind(viewModel: .init(title: title, icon: nil))

        return headerView
    }

    func tableView(_: UITableView, heightForHeaderInSection _: Int) -> CGFloat {
        guard shouldDisplaySectionTitles() else {
            return 0
        }

        return Constants.headerHeight
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        let item = viewModel.sections[indexPath.section].items[indexPath.row]
        presenter.select(viewModel: item)
    }
}

extension HardwareWalletAddressesViewController: HardwareWalletAddressesViewProtocol {
    func didReceive(viewModel: HardwareWalletAddressesViewModel) {
        self.viewModel = viewModel

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

private extension HardwareWalletAddressesViewController {
    enum Constants {
        static let headerHeight: CGFloat = 36
        static let cellHeight: CGFloat = 48
    }
}
