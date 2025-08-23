import UIKit
import Foundation_iOS
import UIKit_iOS

final class AccountManagementViewController: UIViewController, ViewHolder {
    typealias RootViewType = AccountManagementViewLayout

    private enum Constants {
        static let cellHeight: CGFloat = 48.0
        static let headerHeight: CGFloat = 45.0
        static let whenNoTableHeadersTopInset: CGFloat = 16.0
        static let whenHasTableHeadersTopInset: CGFloat = 0.0
    }

    let presenter: AccountManagementPresenterProtocol

    private var walletNameTextField: AnimatedTextField { rootView.headerView.textField }
    private var tableView: UITableView { rootView.tableView }

    private var nameViewModel: InputViewModelProtocol?
    private var hasChanges: Bool = false

    private var walletViewModel: AccountManageWalletViewModel?

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

        tableView.registerHeaderFooterView(
            withClass: ChainAccountListSectionWithActionView.self
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

        applyWalletViewModel()
    }

    private func applyWalletViewModel() {
        guard let walletViewModel = walletViewModel else {
            return
        }

        rootView.headerView.bind(viewModel: walletViewModel)
        reload()
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
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        presenter.selectItem(at: indexPath)
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard let title = presenter.titleForSection(section)?.value(for: selectedLocale) else {
            return nil
        }

        if let action = presenter.actionForSection(section)?.value(for: selectedLocale) {
            let headerView: ChainAccountListSectionWithActionView = tableView.dequeueReusableHeaderFooterView()
            headerView.bind(
                title: title,
                action: action
            ) { [weak self] in
                self?.presenter.activateActionInSection(section)
            }

            return headerView
        } else {
            let headerView: ChainAccountListSectionView = tableView.dequeueReusableHeaderFooterView()
            headerView.bind(description: title)

            return headerView
        }
    }

    func tableView(_: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        guard presenter.titleForSection(section)?.value(for: selectedLocale) != nil else {
            return 0.0
        }

        return Constants.headerHeight
    }
}

// MARK: - AccountManagementViewProtocol

extension AccountManagementViewController: AccountManagementViewProtocol {
    func didReceive(walletViewModel: AccountManageWalletViewModel) {
        self.walletViewModel = walletViewModel

        applyWalletViewModel()
    }

    func didReceive(nameViewModel: InputViewModelProtocol) {
        walletNameTextField.text = nameViewModel.inputHandler.value
        self.nameViewModel = nameViewModel
    }

    func reload() {
        tableView.reloadData()

        if presenter.numberOfSections() > 0, presenter.titleForSection(0) != nil {
            rootView.headerView.bottomInset = Constants.whenHasTableHeadersTopInset
        } else {
            rootView.headerView.bottomInset = Constants.whenNoTableHeadersTopInset
        }

        rootView.updateHeaderLayout()
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
