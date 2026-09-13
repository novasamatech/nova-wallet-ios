import UIKit
import Foundation_iOS
import UIKit_iOS

final class TokensManageViewController: UIViewController, ViewHolder {
    typealias RootViewType = TokensManageViewLayout

    typealias DataSource = UITableViewDiffableDataSource<TokensManageSectionKind, TokensManageListItem>
    typealias Snapshot = NSDiffableDataSourceSnapshot<TokensManageSectionKind, TokensManageListItem>

    let presenter: TokensManagePresenterProtocol

    private lazy var dataSource = makeDataSource()
    private var sections: [TokensManageSection] = []

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
        setupTableView()
        setupLocalization()

        presenter.setup()
    }
}

// MARK: Private

private extension TokensManageViewController {
    func setupTopBar() {
        navigationItem.rightBarButtonItem = rootView.addTokenButton

        rootView.addTokenButton.target = self
        rootView.addTokenButton.action = #selector(actionAddToken)
    }

    func setupSearchField() {
        rootView.searchTextField.addTarget(
            self,
            action: #selector(actionSearchEditingChanged),
            for: .editingChanged
        )

        rootView.searchTextField.delegate = self
    }

    func setupTableView() {
        rootView.tableView.delegate = self
        rootView.tableView.registerClassesForCell([
            TokensManageRootCell.self,
            TokensManageNetworkChildCell.self,
            TokensManageTokenChildCell.self
        ])
        rootView.tableView.registerHeaderFooterView(withClass: TokensManageSectionHeaderView.self)
    }

    func setupLocalization() {
        let languages = selectedLocale.rLanguages

        title = R.string(preferredLanguages: languages).localizable.tokensManageTitle()

        rootView.addTokenButton.title = R.string(preferredLanguages: languages).localizable.commonAddToken()

        let placeholder = R.string(preferredLanguages: languages).localizable.assetsSearchPlaceholder()

        rootView.searchTextField.attributedPlaceholder = NSAttributedString(
            string: placeholder,
            attributes: [
                NSAttributedString.Key.foregroundColor: R.color.colorHintText()!
            ]
        )
    }

    func item(for cell: UITableViewCell) -> TokensManageListItem? {
        guard let indexPath = rootView.tableView.indexPath(for: cell) else {
            return nil
        }

        return dataSource.itemIdentifier(for: indexPath)
    }

    func makeDataSource() -> DataSource {
        .init(tableView: rootView.tableView) { [weak self] tableView, _, item in
            switch item {
            case let .root(viewModel):
                let cell = tableView.dequeueReusableCellWithType(TokensManageRootCell.self)
                cell?.delegate = self
                cell?.bind(viewModel: viewModel)
                return cell
            case let .child(viewModel):
                return self?.createChildCell(for: viewModel, in: tableView)
            }
        }
    }

    func createChildCell(for viewModel: TokensManageChildViewModel, in tableView: UITableView) -> UITableViewCell? {
        switch viewModel.kind {
        case .network:
            let cell = tableView.dequeueReusableCellWithType(TokensManageNetworkChildCell.self)
            cell?.delegate = self
            cell?.bind(viewModel: viewModel)
            return cell
        case .token:
            let cell = tableView.dequeueReusableCellWithType(TokensManageTokenChildCell.self)
            cell?.delegate = self
            cell?.bind(viewModel: viewModel)
            return cell
        }
    }

    func rowHeight(for item: TokensManageListItem?) -> CGFloat {
        switch item {
        case .root:
            return TokensManageRootCell.Constants.height
        case let .child(viewModel):
            return viewModel.kind == .network
                ? TokensManageNetworkChildCell.Constants.height
                : TokensManageTokenChildCell.Constants.height
        case nil:
            return 0
        }
    }

    @objc func actionAddToken() {
        presenter.performAddToken()
    }

    @objc func actionSearchEditingChanged() {
        let query = rootView.searchTextField.text ?? ""

        presenter.search(query: query)
    }
}

// MARK: TokensManageRootCellDelegate

extension TokensManageViewController: TokensManageRootCellDelegate {
    func rootCellDidSwitch(_ cell: TokensManageRootCell, isOn: Bool) {
        guard case let .root(viewModel)? = item(for: cell) else {
            return
        }

        presenter.performSwitch(for: viewModel, isOn: isOn)
    }
}

// MARK: TokensManageChildCellDelegate

extension TokensManageViewController: TokensManageChildCellDelegate {
    func childCellDidSwitch(_ cell: UITableViewCell, isOn: Bool) {
        guard case let .child(viewModel)? = item(for: cell) else {
            return
        }

        presenter.performSwitch(for: viewModel, isOn: isOn)
    }
}

// MARK: UITableViewDelegate

extension TokensManageViewController: UITableViewDelegate {
    func tableView(_: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard case let .root(viewModel)? = dataSource.itemIdentifier(for: indexPath) else {
            return
        }

        presenter.performExpand(for: viewModel)
    }

    func tableView(_: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        rowHeight(for: dataSource.itemIdentifier(for: indexPath))
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard let title = sections[safe: section]?.title else {
            return nil
        }

        let headerView: TokensManageSectionHeaderView = tableView.dequeueReusableHeaderFooterView()
        headerView.bind(title: title)

        return headerView
    }

    func tableView(_: UITableView, heightForHeaderInSection _: Int) -> CGFloat {
        TokensManageSectionHeaderView.Constants.titleHeight
    }
}

// MARK: TokensManageViewProtocol

extension TokensManageViewController: TokensManageViewProtocol {
    func didReceive(sections: [TokensManageSection]) {
        self.sections = sections

        var snapshot = Snapshot()
        snapshot.appendSections(sections.map(\.kind))

        sections.forEach { section in
            snapshot.appendItems(section.items, toSection: section.kind)
        }

        dataSource.apply(snapshot, animatingDifferences: false)

        reloadEmptyState(animated: false)
    }
}

// MARK: EmptyState

extension TokensManageViewController: EmptyStateViewOwnerProtocol {
    var emptyStateDelegate: EmptyStateDelegate { self }
    var emptyStateDataSource: EmptyStateDataSource { self }
}

extension TokensManageViewController: EmptyStateDataSource {
    var viewForEmptyState: UIView? {
        let emptyView = EmptyStateView()
        emptyView.image = R.image.iconLoadingError()!
        emptyView.title = R.string(preferredLanguages: selectedLocale.rLanguages).localizable.assetsSearchEmpty()
        emptyView.titleColor = R.color.colorTextSecondary()!
        emptyView.titleFont = .regularFootnote
        return emptyView
    }

    var contentViewForEmptyState: UIView {
        rootView.contentView
    }
}

extension TokensManageViewController: EmptyStateDelegate {
    var shouldDisplayEmptyState: Bool {
        let hasQuery = !(rootView.searchTextField.text ?? "").isEmpty
        let hasNoItems = dataSource.snapshot().numberOfItems == 0

        return hasQuery && hasNoItems
    }
}

// MARK: UITextFieldDelegate

extension TokensManageViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return false
    }
}

// MARK: Localizable

extension TokensManageViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
            reloadEmptyState(animated: false)
        }
    }
}
