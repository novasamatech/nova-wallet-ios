import UIKit
import SoraFoundation
import SoraUI

final class AccountManagementViewController: UIViewController, ViewHolder {
    typealias RootViewType = AccountManagementViewLayout

    private enum Constants {
        static let cellHeight: CGFloat = 48.0
        static let addActionVerticalInset: CGFloat = 16
    }

    let presenter: AccountManagementPresenterProtocol

    private var walletNameTextField: AnimatedTextField { rootView.headerView.textField }
    private var tableView: UITableView { rootView.tableView }

    private var nameViewModel: InputViewModelProtocol?
    private var hasChanges: Bool = false

    private var walletType: WalletsListSectionViewModel.SectionType = .secrets

    init(presenter: AccountManagementPresenterProtocol, localizationManager: LocalizationManagerProtocol) {
        self.presenter = presenter

        super.init(nibName: nil, bundle: nil)

        self.localizationManager = localizationManager
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = AccountManagementViewLayout()
    }

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

        walletNameTextField.addTarget(self, action: #selector(textFieldDidChange), for: .editingChanged)
    }

    private func setupTableView() {
        tableView.registerHeaderFooterView(
            withClass: ChainAccountListSectionView.self
        )

        tableView.register(R.nib.accountTableViewCell)
        tableView.rowHeight = Constants.cellHeight

        tableView.dataSource = self
        tableView.delegate = self
    }

    private func setupLocalization() {
        let locale = localizationManager?.selectedLocale

        title = R.string.localizable.walletChainManagementTitle(preferredLanguages: locale?.rLanguages)

        walletNameTextField.title = R.string.localizable
            .walletUsernameSetupChooseTitle_v2_2_0(preferredLanguages: locale?.rLanguages)

        applyWalletType()
    }

    private func applyWalletType() {
        switch walletType {
        case .secrets:
            rootView.headerView.showsHintView = false
        case .watchOnly:
            rootView.headerView.showsHintView = true

            let text = R.string.localizable.accountManagementWatchOnlyHint(
                preferredLanguages: selectedLocale.rLanguages
            )
            let icon = R.image.iconWatchOnly()
            rootView.headerView.bindHint(text: text, icon: icon)
        case .paritySigner:
            rootView.headerView.showsHintView = true

            let text = R.string.localizable.paritySignerDetailsHint(
                preferredLanguages: selectedLocale.rLanguages
            )
            let icon = R.image.iconParitySigner()
            rootView.headerView.bindHint(text: text, icon: icon)
        }

        rootView.updateHeaderLayout()
    }

    // MARK: - Actions

    @objc private func textFieldDidChange() {
        hasChanges = true

        if nameViewModel?.inputHandler.value != walletNameTextField.text {
            walletNameTextField.text = nameViewModel?.inputHandler.value
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
    func set(walletType: WalletsListSectionViewModel.SectionType) {
        self.walletType = walletType

        applyWalletType()
    }

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
