import UIKit
import SoraFoundation
import SoraUI

final class ReferendumSearchViewController: BaseTableSearchViewController {
    var presenter: ReferendumSearchPresenterProtocol? {
        basePresenter as? ReferendumSearchPresenterProtocol
    }

    typealias DataSource = UITableViewDiffableDataSource<UITableView.Section, ReferendumIdLocal>
    typealias Snapshot = NSDiffableDataSourceSnapshot<UITableView.Section, ReferendumIdLocal>
    private var dataStore: [ReferendumIdLocal: ReferendumsCellViewModel] = [:]
    private lazy var dataSource = createDataSource()
    private(set) var emptyStateType: EmptyState? = .start

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
        setupHandlers()

        super.viewDidLoad()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        rootView.searchView.searchBar.becomeFirstResponder()
    }

    private func setupLocalization() {
        title = ""

        rootView.searchField.placeholder = R.string.localizable.governanceReferendumsSearchFieldPlaceholder(
            preferredLanguages: selectedLocale.rLanguages
        )

        rootView.apply(style: .init(
            background: .multigradient,
            cancelButtonTitle: R.string.localizable.commonCancel(preferredLanguages: selectedLocale.rLanguages),
            contentInsets: .init(top: 16, left: 0, bottom: 0, right: 0)
        ))
    }

    private func setupHandlers() {
        rootView.cancelButton.addTarget(self, action: #selector(cancelAction), for: .touchUpInside)
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

    private func updateTime(
        in model: ReferendumView.Model,
        time: StatusTimeViewModel??
    ) -> ReferendumView.Model {
        var updatingValue = model
        updatingValue.referendumInfo.time = time??.viewModel
        return updatingValue
    }

    @objc
    private func cancelAction() {
        presenter?.cancel()
    }

    private func update(viewModels: [ReferendumsCellViewModel]) {
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
}

extension ReferendumSearchViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        guard let identifier = dataSource.itemIdentifier(for: indexPath) else {
            return
        }

        presenter?.select(referendumIndex: identifier)
    }
}

extension ReferendumSearchViewController: ReferendumSearchViewProtocol {
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

    func updateReferendums(time: [UInt: StatusTimeViewModel?]) {
        guard let visibleRows = rootView.tableView.indexPathsForVisibleRows else {
            return
        }

        let visibleModelIds = visibleRows.compactMap {
            dataSource.itemIdentifier(for: $0)
        }

        dataStore = time.reduce(into: dataStore) { store, keyValue in
            let modelId = keyValue.key
            guard let model = store[modelId] else {
                return
            }

            switch model.viewModel {
            case let .loaded(value):
                let newValue = updateTime(in: value, time: time[modelId])
                store[modelId] = ReferendumsCellViewModel(
                    referendumIndex: modelId,
                    viewModel: .loaded(value: newValue)
                )
            case let .cached(value):
                let newValue = updateTime(in: value, time: time[modelId])
                store[modelId] = ReferendumsCellViewModel(
                    referendumIndex: modelId,
                    viewModel: .cached(value: newValue)
                )
            case .loading:
                store[modelId] = ReferendumsCellViewModel(
                    referendumIndex: modelId,
                    viewModel: .loading
                )
            }
        }

        var newSnapshot = dataSource.snapshot()
        newSnapshot.reloadItems(visibleModelIds)
        dataSource.apply(newSnapshot, animatingDifferences: false)
    }
}

extension ReferendumSearchViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}
