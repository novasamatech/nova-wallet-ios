import UIKit
import Foundation_iOS

final class NotificationsManagementViewController: UIViewController, ViewHolder {
    typealias DataSource = SettingsTableDataSource<NotificationsManagementRow, NotificationsManagementSection>
    typealias RootViewType = NotificationsManagementViewLayout

    let presenter: NotificationsManagementPresenterProtocol
    let externalCallbacks: NotificationsManagementExternalCallbacks

    lazy var tableDataSource: DataSource = .init()
    private var saveButtonEnabled: Bool = false

    init(
        presenter: NotificationsManagementPresenterProtocol,
        externalCallbacks: NotificationsManagementExternalCallbacks,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.presenter = presenter
        self.externalCallbacks = externalCallbacks
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

    private func setupTableView() {
        tableDataSource.registerCells(for: rootView.tableView)
        rootView.tableView.dataSource = tableDataSource
        rootView.tableView.delegate = self
        rootView.tableView.registerHeaderFooterView(withClass: SettingsSectionHeaderView.self)
        rootView.tableView.registerHeaderFooterView(withClass: SettingsSectionFooterView.self)
    }

    private func setupLocalization() {
        let rightBarButtonItemTitle = R.string(preferredLanguages: selectedLocale.rLanguages).localizable.commonSave()
        navigationItem.title = R.string(
            preferredLanguages: selectedLocale.rLanguages
        ).localizable.settingsPushNotifications()
        navigationItem.rightBarButtonItem?.title = rightBarButtonItemTitle
        rootView.footerView.titleLabel.text = R.string(
            preferredLanguages: selectedLocale.rLanguages
        ).localizable.notificationsManagementPoweredBy()
        rootView.tableView.reloadData()
    }

    private func setupNavigationItem() {
        let title = R.string(preferredLanguages: selectedLocale.rLanguages).localizable.commonSave()
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: title,
            style: .plain,
            target: self,
            action: #selector(saveAction)
        )
        navigationItem.rightBarButtonItem?.isEnabled = saveButtonEnabled
        navigationItem.rightBarButtonItem?.tintColor = R.color.colorButtonTextAccent()

        let backButtonItem = UIBarButtonItem(
            image: R.image.iconBack()!,
            style: .plain,
            target: self, action:
            #selector(backAction)
        )
        backButtonItem.tintColor = R.color.colorIconPrimary()!
        navigationItem.leftBarButtonItem = backButtonItem
        navigationItem.leftItemsSupplementBackButton = false
    }

    @objc private func saveAction() {
        presenter.save()
    }

    @objc private func backAction() {
        presenter.back()
    }
}

extension NotificationsManagementViewController: NotificationsManagementViewProtocol {
    func didReceive(sections: [(NotificationsManagementSection, [NotificationsManagementCellModel])]) {
        tableDataSource.sections = sections
        tableDataSource.switchDelegate = self
        rootView.tableView.reloadData()
    }

    func didReceive(isSaveActionAvailabe: Bool) {
        saveButtonEnabled = isSaveActionAvailabe
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

    func getExternalCallbacks() -> NotificationsManagementExternalCallbacks {
        externalCallbacks
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
        section == 0 ? 0 : 57
    }

    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        guard case let .main(warning) = tableDataSource.sections[section].0,
              let text = warning else {
            return nil
        }

        let footer: SettingsSectionFooterView = tableView.dequeueReusableHeaderFooterView()
        footer.titleLabel.text = text
        return footer
    }

    func tableView(_: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        guard case let .main(warning) = tableDataSource.sections[section].0, warning != nil else {
            return .zero
        }
        return UITableView.automaticDimension
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
