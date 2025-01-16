import UIKit
import Foundation_iOS

final class DelegateVotedReferendaViewController: UIViewController, ViewHolder {
    typealias RootViewType = DelegateVotedReferendaViewLayout
    typealias Row = ReferendumIdLocal

    let presenter: DelegateVotedReferendaPresenterProtocol
    let quantityFormatter: LocalizableResource<NumberFormatter>

    typealias DataSource = UITableViewDiffableDataSource<UITableView.Section, ReferendumIdLocal>
    typealias Snapshot = NSDiffableDataSourceSnapshot<UITableView.Section, ReferendumIdLocal>
    private var dataSource: DataSource?
    private var dataStore: [ReferendumIdLocal: ReferendumsCellViewModel] = [:]
    private var localizableTitle: LocalizableResource<String>?
    private var cachedCount: Int?

    init(
        presenter: DelegateVotedReferendaPresenterProtocol,
        quantityFormatter: LocalizableResource<NumberFormatter>,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.presenter = presenter
        self.quantityFormatter = quantityFormatter

        super.init(nibName: nil, bundle: nil)
        self.localizationManager = localizationManager
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = DelegateVotedReferendaViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        dataSource = createDataSource()
        rootView.tableView.dataSource = dataSource
        rootView.tableView.delegate = self

        presenter.setup()
    }

    private func createDataSource() -> DataSource {
        let dataSource = DataSource(tableView: rootView.tableView) { [weak self] tableView, indexPath, modelId in
            let cell: ReferendumTableViewCell = tableView.dequeueReusableCell(for: indexPath)

            if let model = self?.dataStore[modelId] {
                cell.view.bind(viewModel: model.viewModel)
            }

            cell.applyStyle()
            return cell
        }

        dataSource.defaultRowAnimation = .fade
        return dataSource
    }

    private func setupCounter(value: Int?) {
        cachedCount = value
        navigationItem.rightBarButtonItem = nil

        let formatter = quantityFormatter.value(for: selectedLocale)

        guard
            let value = value,
            let valueString = formatter.string(from: value as NSNumber) else {
            return
        }

        rootView.totalRefrendumsLabel.titleLabel.text = valueString
        rootView.totalRefrendumsLabel.sizeToFit()

        navigationItem.rightBarButtonItem = UIBarButtonItem(customView: rootView.totalRefrendumsLabel)
    }

    private func setupLocalization() {
        title = localizableTitle?.value(for: selectedLocale)
        if let count = cachedCount {
            setupCounter(value: count)
        }
    }

    private func updateTime(
        in model: ReferendumView.Model,
        time: StatusTimeViewModel??
    ) -> ReferendumView.Model {
        var updatingValue = model
        updatingValue.referendumInfo.time = time??.viewModel
        return updatingValue
    }
}

extension DelegateVotedReferendaViewController: DelegateVotedReferendaViewProtocol {
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
        dataSource?.apply(snapshot, animatingDifferences: false)

        let loadedViewModelsCount = viewModels.filter { !$0.viewModel.isLoading }.count
        if loadedViewModelsCount > 0 {
            setupCounter(value: loadedViewModelsCount)
        }
    }

    func updateReferendums(time: [UInt: StatusTimeViewModel?]) {
        guard let dataSource = self.dataSource,
              let visibleRows = rootView.tableView.indexPathsForVisibleRows else {
            return
        }

        let visibleModelIds: [Row] = visibleRows.compactMap {
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

    func update(title: LocalizableResource<String>) {
        localizableTitle = title
        self.title = title.value(for: selectedLocale)
    }
}

extension DelegateVotedReferendaViewController: UITableViewDelegate {
    func tableView(_: UITableView, willDisplay cell: UITableViewCell, forRowAt _: IndexPath) {
        (cell as? SkeletonableViewCell)?.updateLoadingState()
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        guard let referendumId = dataSource?.itemIdentifier(for: indexPath) else {
            return
        }

        presenter.selectReferendum(with: referendumId)
    }
}

extension DelegateVotedReferendaViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}
