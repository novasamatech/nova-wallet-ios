import UIKit
import SoraFoundation
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
        presenter.setup()
    }

    private func configureTableView() {
        rootView.tableView.dataSource = self
        rootView.tableView.delegate = self
        rootView.tableView.registerClassForCell(SettingsTableViewCell.self)
        rootView.tableView.registerHeaderFooterView(withClass: SettingsSectionHeaderView.self)
    }

    @objc
    private func handleAccountAction() {
        presenter.handleWalletAction()
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
        let cell = tableView.dequeueReusableCellWithType(SettingsTableViewCell.self)!
        let viewModels = sections[indexPath.section].1
        let cellViewModel = viewModels[indexPath.row]
        cell.bind(viewModel: cellViewModel)

        if viewModels.count > 1 {
            if indexPath.row == viewModels.count - 1 {
                cell.roundView.roundingCorners = [.bottomLeft, .bottomRight]
            } else if indexPath.row == 0 {
                cell.roundView.roundingCorners = [.topLeft, .topRight]
            } else {
                cell.roundView.roundingCorners = []
            }
        } else {
            cell.roundView.roundingCorners = .allCorners
        }

        return cell
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let header: SettingsSectionHeaderView = tableView.dequeueReusableHeaderFooterView()
        let title = sections[section].0.title(for: selectedLocale)
        header.titleLabel.text = title
        return header
    }

    func tableView(_: UITableView, heightForHeaderInSection _: Int) -> CGFloat {
        56
    }
}

extension SettingsViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        let row = sections[indexPath.section].1[indexPath.row].row
        presenter.actionRow(row)
    }
}

extension SettingsViewController: SettingsViewProtocol {
    func didLoad(userViewModel: SettingsAccountViewModel) {
        rootView.headerView.accountDetailsView.iconImage = userViewModel.icon
        rootView.headerView.accountDetailsView.title = userViewModel.name
    }

    func reload(sections: [(SettingsSection, [SettingsCellViewModel])]) {
        self.sections = sections
        rootView.tableView.reloadData()
    }
}

extension SettingsViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            rootView.headerView.titleLabel.text = R.string.localizable
                .tabbarSettingsTitle(preferredLanguages: selectedLocale.rLanguages)
            rootView.footerView.appNameLabel.text = presenter.appNameText
        }
    }
}

extension SettingsViewController: HiddableBarWhenPushed {}
