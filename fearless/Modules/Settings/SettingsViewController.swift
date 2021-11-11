import UIKit
import SoraFoundation
import SubstrateSdk

final class SettingsViewController: UIViewController {
    var presenter: SettingsPresenterProtocol!

    @IBOutlet private var tableView: UITableView!

    private var sections: [(SettingsSection, [SettingsCellViewModel])] = []
    private(set) var userViewModel: ProfileUserViewModelProtocol?

    override func viewDidLoad() {
        super.viewDidLoad()

        applyLocalization()
        configureTableView()

        presenter.setup()
    }

    private func configureTableView() {
        tableView.registerClassForCell(SettingsTableViewCell.self)
        tableView.registerHeaderFooterView(withClass: SettingsSectionHeaderView.self)
        tableView.alwaysBounceVertical = false
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
        let cellViewModel = sections[indexPath.section].1[indexPath.row]
        cell.bind(viewModel: cellViewModel)
        return cell
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let header: SettingsSectionHeaderView = tableView.dequeueReusableHeaderFooterView()
        let title = sections[section].0.title(for: selectedLocale)
        header.titleLabel.text = title
        return header
    }

    func tableView(_: UITableView, heightForHeaderInSection _: Int) -> CGFloat {
        56 // UITableView.automaticDimension
    }
}

extension SettingsViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        presenter.activateOption(at: indexPath.row)
    }
}

extension SettingsViewController: SettingsViewProtocol {
    func didLoad(userViewModel: ProfileUserViewModelProtocol) {
        self.userViewModel = userViewModel
        // TODO: setup icon
    }

    func reload(sections: [(SettingsSection, [SettingsCellViewModel])]) {
        self.sections = sections
        tableView.reloadData()
    }
}

extension SettingsViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {}
    }
}
