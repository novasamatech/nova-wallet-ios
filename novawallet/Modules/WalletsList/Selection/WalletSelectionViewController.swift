import UIKit
import Foundation_iOS

final class WalletSelectionViewController: WalletsListViewController<
    WalletSelectionViewLayout,
    WalletSelectionTableViewCell
> {
    var presenter: WalletSelectionPresenterProtocol? { basePresenter as? WalletSelectionPresenterProtocol }

    init(presenter: WalletSelectionPresenterProtocol, localizationManager: LocalizationManagerProtocol) {
        super.init(basePresenter: presenter, localizationManager: localizationManager)
    }

    override func viewDidLoad() {
        setupSettingsItems()

        super.viewDidLoad()

        rootView.searchTextField.addTarget(
            self,
            action: #selector(searchChanged),
            for: .editingChanged
        )
    }

    @objc private func searchChanged() {
        presenter?.search(query: rootView.searchTextField.text ?? "")
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        presenter?.viewDidDisappear()
    }

    override func setupLocalization() {
        let languages = selectedLocale.rLanguages
        title = R.string(preferredLanguages: languages).localizable.commonSelectWallet()
        rootView.searchTextField.placeholder = R.string(
            preferredLanguages: languages
        ).localizable.commonSearchWalletsPlaceholder()
    }

    private func setupSettingsItems() {
        navigationItem.rightBarButtonItem = rootView.settingsButton
        rootView.settingsButton.target = self
        rootView.settingsButton.action = #selector(actionSettings)
    }

    @objc private func actionSettings() {
        presenter?.activateSettings()
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        super.tableView(tableView, didSelectRowAt: indexPath)

        presenter?.selectItem(at: indexPath.row, section: indexPath.section)
    }
}
