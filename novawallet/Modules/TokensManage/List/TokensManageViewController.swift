import Foundation_iOS
import UIKit
import UIKit_iOS

final class TokensManageViewController: UIViewController, ViewHolder {
    typealias RootViewType = TokensManageViewLayout

    typealias DataSource = UITableViewDiffableDataSource<TokensManageSectionKind, TokensManageListItemIdentifier>
    typealias Snapshot = NSDiffableDataSourceSnapshot<TokensManageSectionKind, TokensManageListItemIdentifier>

    let presenter: TokensManagePresenterProtocol

    private lazy var dataSource = makeDataSource()
    private var sections: [TokensManageSection] = []
    private var itemsByIdentifier: [TokensManageListItemIdentifier: TokensManageListItem] = [:]
    private var animatedRootIdentifiers: Set<TokensManageListItemIdentifier> = []
    private var snapshotVersion: UInt = 0

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
        setupAutoAddView()
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

    func setupAutoAddView() {
        rootView.autoAddView.switchView.addTarget(
            self,
            action: #selector(actionAutoAddChanged),
            for: .valueChanged
        )
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

        rootView.addTokenButton.accessibilityLabel = R.string(
            preferredLanguages: languages
        ).localizable.commonAddToken()
        rootView.autoAddView.titleLabel.text = R.string(preferredLanguages: languages).localizable.tokensManageAutoAdd()

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

        guard let identifier = dataSource.itemIdentifier(for: indexPath) else {
            return nil
        }

        return itemsByIdentifier[identifier]
    }

    func makeDataSource() -> DataSource {
        .init(tableView: rootView.tableView) { [weak self] tableView, _, identifier in
            guard let self, let item = itemsByIdentifier[identifier] else {
                return nil
            }

            switch item {
            case let .root(viewModel):
                let cell = tableView.dequeueReusableCellWithType(TokensManageRootCell.self)
                cell?.delegate = self
                cell?.bind(
                    viewModel: viewModel,
                    animated: animatedRootIdentifiers.contains(identifier)
                )
                return cell
            case let .child(viewModel):
                return createChildCell(for: viewModel, in: tableView)
            }
        }
    }

    func item(at indexPath: IndexPath) -> TokensManageListItem? {
        guard let identifier = dataSource.itemIdentifier(for: indexPath) else {
            return nil
        }

        return itemsByIdentifier[identifier]
    }

    func expandedRootIdentifiers(
        in newItems: [TokensManageListItemIdentifier: TokensManageListItem]
    ) -> Set<TokensManageListItemIdentifier> {
        newItems.reduce(into: []) { result, entry in
            guard
                case let .root(newViewModel) = entry.value,
                case let .root(oldViewModel)? = itemsByIdentifier[entry.key],
                newViewModel.isExpanded != oldViewModel.isExpanded else {
                return
            }

            result.insert(entry.key)
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

    func bind(headerView: TokensManageSectionHeaderView, to section: TokensManageSection) {
        if section.kind == .results {
            headerView.bind(caption: section.title)
        } else {
            headerView.bind(title: section.title)
        }
    }

    func refreshSectionHeaders() {
        for (index, section) in sections.enumerated() {
            guard
                let headerView = rootView.tableView.headerView(
                    forSection: index
                ) as? TokensManageSectionHeaderView else {
                continue
            }

            bind(headerView: headerView, to: section)
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

    @objc func actionAutoAddChanged() {
        presenter.performAutoAddChange(to: rootView.autoAddView.switchView.isOn)
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
        guard case let .root(viewModel)? = item(at: indexPath) else {
            return
        }

        presenter.performExpand(for: viewModel)
    }

    func tableView(_: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        rowHeight(for: item(at: indexPath))
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard let section = sections[safe: section] else {
            return nil
        }

        let headerView: TokensManageSectionHeaderView = tableView.dequeueReusableHeaderFooterView()

        bind(headerView: headerView, to: section)

        return headerView
    }

    func tableView(_: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        sections[safe: section]?.kind == .results
            ? TokensManageSectionHeaderView.Constants.captionHeight
            : TokensManageSectionHeaderView.Constants.titleHeight
    }
}

// MARK: TokensManageViewProtocol

extension TokensManageViewController: TokensManageViewProtocol {
    func didReceive(sections: [TokensManageSection], animated: Bool) {
        snapshotVersion &+= 1
        let appliedSnapshotVersion = snapshotVersion
        let newItems = sections.flatMap(\.items).reduce(into: [:]) { result, item in
            result[item.identifier] = item
        }
        let oldIdentifiers = Set(itemsByIdentifier.keys)
        let newIdentifiers = Set(newItems.keys)

        animatedRootIdentifiers = animated ? expandedRootIdentifiers(in: newItems) : []
        self.sections = sections
        itemsByIdentifier = newItems

        var snapshot = Snapshot()
        snapshot.appendSections(sections.map(\.kind))

        for section in sections {
            snapshot.appendItems(section.items.map(\.identifier), toSection: section.kind)
        }

        snapshot.reconfigureItems(Array(oldIdentifiers.intersection(newIdentifiers)))

        dataSource.apply(snapshot, animatingDifferences: animated) { [weak self] in
            guard let self, snapshotVersion == appliedSnapshotVersion else {
                return
            }

            animatedRootIdentifiers = []
        }

        refreshSectionHeaders()

        reloadEmptyState(animated: animated)
    }

    func didReceive(autoAddTokens: Bool) {
        rootView.autoAddView.bind(isOn: autoAddTokens)
    }
}

// MARK: EmptyState

extension TokensManageViewController: EmptyStateViewOwnerProtocol {
    var emptyStateDelegate: EmptyStateDelegate {
        self
    }

    var emptyStateDataSource: EmptyStateDataSource {
        self
    }
}

extension TokensManageViewController: EmptyStateDataSource {
    var viewForEmptyState: UIView? {
        let emptyView = EmptyStateView()
        emptyView.image = R.image.iconStartSearch()
        emptyView.title = R.string(
            preferredLanguages: selectedLocale.rLanguages
        ).localizable.commonSearchStartTitle_v2_2_0()
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
        let hasNoItems = sections.allSatisfy(\.items.isEmpty)

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
