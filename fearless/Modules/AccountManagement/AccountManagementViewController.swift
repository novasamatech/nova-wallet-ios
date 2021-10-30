import UIKit
import SoraFoundation
import SoraUI

final class AccountManagementViewController: UIViewController {
    private enum Constants {
        static let cellHeight: CGFloat = 48.0
        static let addActionVerticalInset: CGFloat = 16
    }

    var presenter: AccountManagementPresenterProtocol!

    @IBOutlet private var walletNameTextField: AnimatedTextField!
    @IBOutlet private var tableView: UITableView!

    private var nameViewModel: InputViewModelProtocol?
    private var hasChanges: Bool = false

    override func viewDidLoad() {
        super.viewDidLoad()

        setupTextField()
        setupTableView()
        setupLocalization()

        presenter.setup()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        presenter.finalizeName()
    }

    // MARK: - Setup functions

    private func setupTextField() {
        walletNameTextField.textField.returnKeyType = .done
        walletNameTextField.textField.textContentType = .nickname
        walletNameTextField.textField.autocapitalizationType = .none
        walletNameTextField.textField.autocorrectionType = .no
        walletNameTextField.textField.spellCheckingType = .no

        walletNameTextField.delegate = self
    }

    private func setupTableView() {
        tableView.registerHeaderFooterView(
            withClass: ChainAccountListSectionView.self
        )

        tableView.register(R.nib.accountTableViewCell)
        tableView.rowHeight = Constants.cellHeight
    }

    private func setupLocalization() {
        let locale = localizationManager?.selectedLocale

        title = R.string.localizable.walletChainManagementTitle(preferredLanguages: locale?.rLanguages)

        walletNameTextField.title = R.string.localizable
            .walletUsernameSetupChooseTitle(preferredLanguages: locale?.rLanguages)
    }

    // MARK: - Actions

    @IBAction private func textFieldDidChange(_ sender: UITextField) {
        hasChanges = true

        if nameViewModel?.inputHandler.value != sender.text {
            sender.text = nameViewModel?.inputHandler.value
        }
    }
}

// MARK: - AnimatedTextFieldDelegate

extension AccountManagementViewController: AnimatedTextFieldDelegate {
    func animatedTextField(
        _ textField: AnimatedTextField,
        shouldChangeCharactersIn range: NSRange,
        replacementString string: String
    ) -> Bool {
        guard let viewModel = nameViewModel else {
            return true
        }

        let shouldApply = viewModel.inputHandler.didReceiveReplacement(string, for: range)

        if !shouldApply, textField.text != viewModel.inputHandler.value {
            textField.text = viewModel.inputHandler.value
        }

        return shouldApply
    }

    func animatedTextFieldShouldReturn(_ textField: AnimatedTextField) -> Bool {
        textField.resignFirstResponder()
        return false
    }
}

// MARK: - UITableViewDataSource

extension AccountManagementViewController: UITableViewDataSource {
    func numberOfSections(in _: UITableView) -> Int {
        presenter.numberOfSections()
    }

    func tableView(_: UITableView, numberOfRowsInSection section: Int) -> Int {
        presenter.numberOfItems(in: section)
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(
            withIdentifier: R.reuseIdentifier.accountCellId,
            for: indexPath
        )!

        cell.delegate = self

        let item = presenter.item(at: indexPath)
        cell.bind(viewModel: item)

        return cell
    }
}

// MARK: - UITableViewDelegate

extension AccountManagementViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let headerView: ChainAccountListSectionView = tableView.dequeueReusableHeaderFooterView()
        let title = presenter.titleForSection(section).value(for: selectedLocale)
        headerView.bind(description: title.uppercased())

        return headerView
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        presenter.selectItem(at: indexPath)
    }
}

// MARK: - AccountManagementViewProtocol

extension AccountManagementViewController: AccountManagementViewProtocol {
    func set(nameViewModel: InputViewModelProtocol) {
        walletNameTextField.text = nameViewModel.inputHandler.value
        self.nameViewModel = nameViewModel
    }

    func reload() {
        tableView.reloadData()
    }
}

// MARK: - Localizable

extension AccountManagementViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}

// MARK: - AccountTableViewCellDelegate

extension AccountManagementViewController: AccountTableViewCellDelegate {
    func didSelectInfo(_ cell: AccountTableViewCell) {
        guard let indexPath = tableView.indexPath(for: cell) else {
            return
        }

        presenter.activateDetails(at: indexPath)
    }
}
