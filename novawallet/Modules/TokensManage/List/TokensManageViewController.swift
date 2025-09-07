import UIKit
import Foundation_iOS
import UIKit_iOS

final class TokensManageViewController: UIViewController, ViewHolder {
    typealias RootViewType = TokensManageViewLayout

    typealias DataSource = UITableViewDiffableDataSource<UITableView.Section, TokensManageViewModel>
    typealias Snapshot = NSDiffableDataSourceSnapshot<UITableView.Section, TokensManageViewModel>

    let presenter: TokensManagePresenterProtocol

    private lazy var dataSource = makeDataSource()

    init(presenter: TokensManagePresenterProtocol, localizationManager: LocalizationManagerProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)

        self.localizationManager = localizationManager
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = TokensManageViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupTopBar()
        setupSearchField()
        setupFilter()
        setupTableView()
        setupLocalization()

        presenter.setup()
    }

    private func setupTopBar() {
        navigationItem.rightBarButtonItem = rootView.addTokenButton

        rootView.addTokenButton.target = self
        rootView.addTokenButton.action = #selector(actionAddToken)
    }

    private func setupFilter() {
        rootView.filterSwitch.addTarget(
            self,
            action: #selector(actionHideZeroBalances),
            for: .valueChanged
        )
    }

    private func setupSearchField() {
        rootView.searchTextField.addTarget(
            self,
            action: #selector(actionSearchEditingChanged),
            for: .editingChanged
        )

        rootView.searchTextField.delegate = self
    }

    private func setupTableView() {
        rootView.tableView.rowHeight = 56
        rootView.tableView.registerClassForCell(TokensManageTableViewCell.self)
    }

    private func setupLocalization() {
        let languages = selectedLocale.rLanguages

        title = R.string(preferredLanguages: languages
        ).localizable.tokensManageTitle()

        rootView.addTokenButton.title = R.string(preferredLanguages: languages
        ).localizable.commonAddToken()

        let placeholder = R.string(preferredLanguages: languages
        ).localizable.assetsSearchPlaceholder()

        rootView.filterLabel.text = R.string(preferredLanguages: languages
        ).localizable.assetsManageHideZeroBalances()

        rootView.searchTextField.attributedPlaceholder = NSAttributedString(
            string: placeholder,
            attributes: [
                NSAttributedString.Key.foregroundColor: R.color.colorHintText()!
            ]
        )
    }

    private func getViewModel(for cell: TokensManageTableViewCell) -> TokensManageViewModel? {
        guard
            let indexPath = rootView.tableView.indexPath(for: cell),
            let viewModel = dataSource.itemIdentifier(for: indexPath) else {
            return nil
        }

        return viewModel
    }

    private func makeDataSource() -> DataSource {
        .init(tableView: rootView.tableView) { [weak self] tableView, _, viewModel in
            let cell = tableView.dequeueReusableCellWithType(TokensManageTableViewCell.self)
            cell?.delegate = self

            cell?.bind(viewModel: viewModel)

            return cell
        }
    }

    @objc private func actionAddToken() {
        presenter.performAddToken()
    }

    @objc private func actionSearchEditingChanged() {
        let query = rootView.searchTextField.text ?? ""

        presenter.search(query: query)
    }

    @objc private func actionHideZeroBalances() {
        presenter.performFilterChange(to: rootView.filterSwitch.isOn)
    }
}

extension TokensManageViewController: TokensManageTableViewCellDelegate {
    func tokensManageCellDidEdit(_ cell: TokensManageTableViewCell) {
        guard let viewModel = getViewModel(for: cell) else {
            return
        }

        presenter.performEdit(for: viewModel)
    }

    func tokensManageCellDidSwitch(_ cell: TokensManageTableViewCell, isOn: Bool) {
        guard let viewModel = getViewModel(for: cell) else {
            return
        }

        presenter.performSwitch(for: viewModel, enabled: isOn)
    }
}

extension TokensManageViewController: TokensManageViewProtocol {
    func didReceive(hidesZeroBalances: Bool) {
        rootView.filterSwitch.setOn(
            hidesZeroBalances,
            animated: true
        )
    }

    func didReceive(viewModels: [TokensManageViewModel]) {
        var snapshot = Snapshot()
        snapshot.appendSections([.main])
        snapshot.appendItems(viewModels)

        dataSource.apply(snapshot, animatingDifferences: false)

        reloadEmptyState(animated: false)
    }
}

extension TokensManageViewController: EmptyStateViewOwnerProtocol {
    var emptyStateDelegate: EmptyStateDelegate { self }
    var emptyStateDataSource: EmptyStateDataSource { self }
}

extension TokensManageViewController: EmptyStateDataSource {
    var viewForEmptyState: UIView? {
        let emptyView = EmptyStateView()
        emptyView.image = R.image.iconLoadingError()!
        emptyView.title = R.string(preferredLanguages: selectedLocale.rLanguages
        ).localizable.assetsSearchEmpty()
        emptyView.titleColor = R.color.colorTextSecondary()!
        emptyView.titleFont = .regularFootnote
        return emptyView
    }

    var contentViewForEmptyState: UIView {
        rootView.contentView
    }
}

extension TokensManageViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return false
    }
}

extension TokensManageViewController: EmptyStateDelegate {
    var shouldDisplayEmptyState: Bool {
        let hasQuery = !(rootView.searchTextField.text ?? "").isEmpty
        let hasNoItems = dataSource.snapshot().numberOfItems(inSection: .main) == 0

        return hasQuery && hasNoItems
    }
}

extension TokensManageViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
            reloadEmptyState(animated: false)
        }
    }
}
