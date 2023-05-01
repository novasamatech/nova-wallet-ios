import UIKit
import SoraFoundation
import SoraUI

final class ReferendumSearchViewController: BaseTableSearchViewController {
    enum EmptyStateType {
        case notFound
        case start
    }

    var presenter: ReferendumSearchPresenterProtocol? {
        basePresenter as? ReferendumSearchPresenterProtocol
    }

    typealias DataSource = UITableViewDiffableDataSource<UITableView.Section, ReferendumIdLocal>
    typealias Snapshot = NSDiffableDataSourceSnapshot<UITableView.Section, ReferendumIdLocal>
    private var dataStore: [ReferendumIdLocal: ReferendumsCellViewModel] = [:]
    private lazy var dataSource = createDataSource()
    private var emptyStateType: EmptyStateType? = .start

    init(presenter: ReferendumSearchPresenterProtocol, localizationManager: LocalizationManagerProtocol) {
        super.init(basePresenter: presenter)

        self.localizationManager = localizationManager
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        setupTableView()
        applyLocalization()
        applyState()
        super.viewDidLoad()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        rootView.searchView.searchBar.becomeFirstResponder()
    }

    private func setupLocalization() {
        title = R.string.localizable.commonSearch(preferredLanguages: selectedLocale.rLanguages)

        rootView.searchField.placeholder = R.string.localizable.searchByAddressNamePlaceholder(
            preferredLanguages: selectedLocale.rLanguages
        )

        rootView.apply(style: .init(
            background: .multigradient,
            cancelButtonTitle: R.string.localizable.commonCancel(preferredLanguages: selectedLocale.rLanguages),
            contentInsets: .init(top: 16, left: 0, bottom: 0, right: 0)
        ))
    }

    private func applyState() {
        rootView.tableView.isHidden = shouldDisplayEmptyState
        reloadEmptyState(animated: false)
    }

    private func setupTableView() {
        rootView.tableView.separatorStyle = .none
        rootView.tableView.dataSource = dataSource
        rootView.tableView.delegate = self

        rootView.tableView.registerClassForCell(ReferendumTableViewCell.self)
    }

    private func createDataSource() -> DataSource {
        let dataSource: DataSource = .init(
            tableView: rootView.tableView
        ) { [weak self] tableView, indexPath, model -> UITableViewCell? in
            guard let self = self else {
                return nil
            }
            let cell: ReferendumTableViewCell = tableView.dequeueReusableCell(for: indexPath)
            dataStore[model].map {
                cell.view.bind(viewModel: $0.viewModel)
                cell.applyStyle()
            }
            return cell
        }

        return dataSource
    }
}

extension ReferendumSearchViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
    }
}

// MARK: - EmptyStateViewOwnerProtocol

extension ReferendumSearchViewController: EmptyStateViewOwnerProtocol {
    var emptyStateDelegate: EmptyStateDelegate { self }
    var emptyStateDataSource: EmptyStateDataSource { self }
}

// MARK: - EmptyStateDataSource

extension ReferendumSearchViewController: EmptyStateDataSource {
    var viewForEmptyState: UIView? {
        guard let emptyStateType = emptyStateType else {
            return nil
        }

        let emptyView = EmptyStateView()

        switch emptyStateType {
        case .notFound:
            emptyView.image = R.image.iconEmptySearch()
            emptyView.title = R.string.localizable.walletSearchEmptyTitle_v1100(
                preferredLanguages: selectedLocale.rLanguages
            )
        case .start:
            emptyView.image = R.image.iconStartSearch()
            emptyView.title = R.string.localizable.commonSearchStartTitle_v2_2_0(
                preferredLanguages: selectedLocale.rLanguages
            )
        }

        emptyView.titleColor = R.color.colorTextSecondary()!
        emptyView.titleFont = .p2Paragraph

        return emptyView
    }

    var contentViewForEmptyState: UIView {
        rootView.emptyStateContainer
    }

    var verticalSpacingForEmptyState: CGFloat? { 0 }
}

// MARK: - EmptyStateDelegate

extension ReferendumSearchViewController: EmptyStateDelegate {
    var shouldDisplayEmptyState: Bool {
        emptyStateType != nil
    }
}

extension ReferendumSearchViewController: ReferendumSearchViewProtocol {
    func update(viewModels: [ReferendumsCellViewModel]) {
        let existingIds = viewModels.compactMap { model in
            if dataStore[model.referendumIndex] != nil {
                return model.referendumIndex
            } else {
                return nil
            }
        }

        dataStore = viewModels.reduce(
            into: [ReferendumIdLocal: ReferendumsCellViewModel]()
        ) {
            $0[$1.referendumIndex] = $1
        }

        let newIds = viewModels.map(\.referendumIndex)

        var snapshot = Snapshot()
        snapshot.appendSections([.main])
        snapshot.appendItems(newIds)
        snapshot.reloadItems(existingIds)
        dataSource.apply(snapshot, animatingDifferences: false)
    }

    func didReceive(viewModel: TableSearchResultViewModel<ReferendumsCellViewModel>) {
        switch viewModel {
        case .start:
            emptyStateType = .start
        case .notFound:
            emptyStateType = .notFound
        case let .found(_, viewModels):
            emptyStateType = nil
            update(viewModels: viewModels)
        }

        applyState()
    }
}

// MARK: - Localizable

extension ReferendumSearchViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}
