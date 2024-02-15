import SoraFoundation

final class NotificationsManagementViewController: UIViewController, ViewHolder {
    typealias DataSource = SettingsTableDataSource<NotificationsManagementRow, NotificationsManagementSection>
    typealias RootViewType = NotificationsManagementViewLayout

    let presenter: NotificationsManagementPresenterProtocol
    lazy var tableDataSource: DataSource = .init()
    private var saveButtonEnabled: Bool = false

    init(
        presenter: NotificationsManagementPresenterProtocol,
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
        view = NotificationsManagementViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupNavigationItem()
        setupTableView()
        setupLocalization()
        presenter.setup()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        presenter.viewWillAppear()
    }

    private func setupTableView() {
        tableDataSource.registerCells(for: rootView.tableView)
        rootView.tableView.dataSource = tableDataSource
        rootView.tableView.delegate = self
        rootView.tableView.registerHeaderFooterView(withClass: SettingsSectionHeaderView.self)
    }

    private func setupLocalization() {
        let rightBarButtonItemTitle = R.string.localizable.commonSave(
            preferredLanguages: selectedLocale.rLanguages)
        navigationItem.title = R.string.localizable.settingsPushNotifications(
            preferredLanguages: selectedLocale.rLanguages
        )
        navigationItem.rightBarButtonItem?.title = rightBarButtonItemTitle
        rootView.footerView.titleLabel.text = R.string.localizable.notificationsManagementPoweredBy(
            preferredLanguages: selectedLocale.rLanguages
        )
        rootView.tableView.reloadData()
    }

    private func setupNavigationItem() {
        let title = R.string.localizable.commonSave(preferredLanguages: selectedLocale.rLanguages)
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: title,
            style: .plain,
            target: self,
            action: #selector(saveAction)
        )
        navigationItem.rightBarButtonItem?.isEnabled = saveButtonEnabled
        navigationItem.rightBarButtonItem?.tintColor = R.color.colorButtonTextAccent()
    }

    @objc private func saveAction() {
        presenter.save()
    }
}

extension NotificationsManagementViewController: NotificationsManagementViewProtocol {
    func didReceive(sections: [(NotificationsManagementSection, [NotificationsManagementCellModel])]) {
        tableDataSource.sections = sections
        tableDataSource.switchDelegate = self
        rootView.tableView.reloadData()
    }

    func didReceive(isSaveActionAvailabe: Bool) {
        navigationItem.rightBarButtonItem?.isEnabled = isSaveActionAvailabe
    }

    func startLoading() {
        let activityIndicator = UIActivityIndicatorView()
        navigationItem.rightBarButtonItem = .init(customView: activityIndicator)
        activityIndicator.startAnimating()
    }

    func stopLoading() {
        setupNavigationItem()
    }
}

extension NotificationsManagementViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        let row = tableDataSource.sections[indexPath.section].1[indexPath.row].row
        presenter.actionRow(row)
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let header: SettingsSectionHeaderView = tableView.dequeueReusableHeaderFooterView()
        let title = tableDataSource.sections[section].0.title(for: selectedLocale)
        header.titleLabel.text = title
        return header
    }

    func tableView(_: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        section == 0 ? 0 : 37
    }
}

extension NotificationsManagementViewController: SwitchSettingsTableViewCellDelegate {
    func didToggle(cell: SwitchSettingsTableViewCell) {
        guard let indexPath = rootView.tableView.indexPath(for: cell) else {
            return
        }

        let viewModels = tableDataSource.sections[indexPath.section].1
        let cellViewModel = viewModels[indexPath.row]

        presenter.actionRow(cellViewModel.row)
    }
}

extension NotificationsManagementViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}
