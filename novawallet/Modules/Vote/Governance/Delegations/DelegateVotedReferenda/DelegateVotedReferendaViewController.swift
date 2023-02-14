import UIKit
import SoraFoundation

final class DelegateVotedReferendaViewController: UIViewController, ViewHolder {
    typealias RootViewType = DelegateVotedReferendaViewLayout
    typealias Row = ReferendumsCellViewModel

    let presenter: DelegateVotedReferendaPresenterProtocol
    let quantityFormatter: LocalizableResource<NumberFormatter>

    typealias DataSource = UITableViewDiffableDataSource<UITableView.Section, Row>
    typealias Snapshot = NSDiffableDataSourceSnapshot<UITableView.Section, Row>
    private var dataSource: DataSource?
    private var localizableTitle: LocalizableResource<String>?

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
        let dataSource = DataSource(tableView: rootView.tableView) { tableView, indexPath, model in
            let cell: ReferendumTableViewCell = tableView.dequeueReusableCell(for: indexPath)
            cell.view.bind(viewModel: model.viewModel)
            cell.applyStyle()
            return cell
        }

        dataSource.defaultRowAnimation = .fade
        return dataSource
    }

    private func setupCounter(value: Int?) {
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
        if let count = dataSource?.snapshot().numberOfItems {
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
        var snapshot = Snapshot()
        snapshot.appendSections([.main])
        snapshot.appendItems(viewModels)
        dataSource?.apply(snapshot, animatingDifferences: false)
        setupCounter(value: viewModels.count)
    }

    func updateReferendums(time: [UInt: StatusTimeViewModel?]) {
        guard let dataSource = self.dataSource,
              let visibleRows = rootView.tableView.indexPathsForVisibleRows else {
            return
        }

        let visibleItems = visibleRows.compactMap(dataSource.itemIdentifier).compactMap {
            switch $0.viewModel {
            case let .loaded(value):
                let newValue = updateTime(in: value, time: time[$0.referendumIndex])
                return Row(
                    referendumIndex: $0.referendumIndex,
                    viewModel: .loaded(value: newValue)
                )
            case let .cached(value):
                let newValue = updateTime(in: value, time: time[$0.referendumIndex])
                return Row(
                    referendumIndex: $0.referendumIndex,
                    viewModel: .cached(value: newValue)
                )
            case .loading:
                return Row(
                    referendumIndex: $0.referendumIndex,
                    viewModel: .loading
                )
            }
        }

        var newSnapshot = dataSource.snapshot()
        newSnapshot.reloadItems(visibleItems)
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
}

extension DelegateVotedReferendaViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}
