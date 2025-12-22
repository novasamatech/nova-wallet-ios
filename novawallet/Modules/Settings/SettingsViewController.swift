import UIKit
import Foundation_iOS
import SubstrateSdk

final class SettingsViewController: UIViewController, ViewHolder {
    typealias RootViewType = SettingsViewLayout

    var presenter: SettingsPresenterProtocol!

    private var sections: [(SettingsSection, [SettingsCellViewModel])] = []

    override func loadView() {
        view = SettingsViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        applyLocalization()
        configureTableView()

        rootView.headerView.accountDetailsView.addTarget(
            self,
            action: #selector(handleAccountAction),
            for: .touchUpInside
        )

        rootView.headerView.walletSwitch.addTarget(
            self,
            action: #selector(handleSwitchAction),
            for: .touchUpInside
        )

        presenter.setup()
    }

    private func configureTableView() {
        rootView.tableView.dataSource = self
        rootView.tableView.delegate = self
        rootView.tableView.registerClassForCell(SettingsTableViewCell.self)
        rootView.tableView.registerClassForCell(SwitchSettingsTableViewCell.self)
        rootView.tableView.registerClassForCell(SettingsSubtitleTableViewCell.self)
        rootView.tableView.registerClassForCell(SettingsBoxTableViewCell.self)
        rootView.tableView.registerHeaderFooterView(withClass: SettingsSectionHeaderView.self)
    }

    @objc private func handleAccountAction() {
        presenter.handleWalletAction()
    }

    @objc private func handleSwitchAction() {
        presenter.handleSwitchAction()
    }
}

extension SettingsViewController: UITableViewDataSource {
    func numberOfSections(in _: UITableView) -> Int {
        sections.count
    }

    func tableView(_: UITableView, numberOfRowsInSection section: Int) -> Int {
        sections[section].1.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let viewModels = sections[indexPath.section].1
        let cellViewModel = viewModels[indexPath.row]

        let cell: UITableViewCell & TableViewCellPositioning

        switch cellViewModel.accessory {
        case let .title(viewModel):
            let subtitleCell = tableView.dequeueReusableCellWithType(SettingsSubtitleTableViewCell.self)!
            subtitleCell.bind(titleViewModel: cellViewModel.title, accessoryViewModel: viewModel)
            cell = subtitleCell
        case let .box(viewModel):
            let boxCell = tableView.dequeueReusableCellWithType(SettingsBoxTableViewCell.self)!
            boxCell.bind(titleViewModel: cellViewModel.title, accessoryViewModel: viewModel)
            cell = boxCell
        case let .switchControl(isOn):
            let switchCell = tableView.dequeueReusableCellWithType(SwitchSettingsTableViewCell.self)!
            switchCell.bind(titleViewModel: cellViewModel.title, isOn: isOn)
            switchCell.delegate = self
            cell = switchCell
        case .none:
            let titleCell = tableView.dequeueReusableCellWithType(SettingsTableViewCell.self)!
            titleCell.bind(titleViewModel: cellViewModel.title)
            cell = titleCell
        }

        cell.apply(position: .init(row: indexPath.row, count: viewModels.count))

        return cell
    }
}

extension SettingsViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        let row = sections[indexPath.section].1[indexPath.row].row
        presenter.actionRow(row)
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let header: SettingsSectionHeaderView = tableView.dequeueReusableHeaderFooterView()
        let title = sections[section].0.title(for: selectedLocale)
        header.titleLabel.text = title
        return header
    }

    func tableView(_: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        section == 0 ? 57.0 : 37.0
    }
}

extension SettingsViewController: SettingsViewProtocol {
    func didLoad(userViewModel: SettingsAccountViewModel) {
        rootView.headerView.accountDetailsView.iconImage = userViewModel.icon
        rootView.headerView.accountDetailsView.title = userViewModel.name

        let walletSwitchViewModel = WalletSwitchViewModel(
            identifier: userViewModel.identifier,
            type: userViewModel.walletType,
            iconViewModel: userViewModel.icon.map { StaticImageViewModel(image: $0) },
            hasNotification: userViewModel.hasWalletNotification
        )

        rootView.headerView.walletSwitch.bind(viewModel: walletSwitchViewModel)
    }

    func reload(sections: [(SettingsSection, [SettingsCellViewModel])]) {
        self.sections = sections
        rootView.tableView.reloadData()
    }
}

extension SettingsViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            rootView.headerView.titleLabel.text = R.string(preferredLanguages: selectedLocale.rLanguages).localizable
                .tabbarSettingsTitle()
            rootView.footerView.appNameLabel.text = presenter.appNameText
        }
    }
}

extension SettingsViewController: SwitchSettingsTableViewCellDelegate {
    func didToggle(cell: SwitchSettingsTableViewCell) {
        guard let indexPath = rootView.tableView.indexPath(for: cell) else {
            return
        }

        let viewModels = sections[indexPath.section].1
        let cellViewModel = viewModels[indexPath.row]

        presenter.actionRow(cellViewModel.row)
    }
}

extension SettingsViewController: HiddableBarWhenPushed {}
