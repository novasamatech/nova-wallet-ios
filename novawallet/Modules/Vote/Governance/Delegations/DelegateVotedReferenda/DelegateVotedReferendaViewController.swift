import UIKit

final class DelegateVotedReferendaViewController: UIViewController, ViewHolder {
    typealias RootViewType = DelegateVotedReferendaViewLayout
    typealias Row = ReferendumsCellViewModel

    let presenter: DelegateVotedReferendaPresenterProtocol
    typealias DataSource = UITableViewDiffableDataSource<UITableView.Section, Row>
    typealias Snapshot = NSDiffableDataSourceSnapshot<UITableView.Section, Row>
    private var dataSource: DataSource?

    init(presenter: DelegateVotedReferendaPresenterProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
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

        presenter.setup()
    }

    private func createDataSource() -> DataSource {
        let dataSource = DataSource(tableView: rootView.tableView) { tableView, indexPath, model in
            let cell: ReferendumTableViewCell = tableView.dequeueReusableCell(for: indexPath)
            cell.view.bind(viewModel: model.viewModel)
            return cell
        }

        dataSource.defaultRowAnimation = .fade
        return dataSource
    }
}

extension DelegateVotedReferendaViewController: DelegateVotedReferendaViewProtocol {
    func update(viewModels: [ReferendumsCellViewModel]) {
        var snapshot = Snapshot()
        snapshot.appendSections([.main])
        snapshot.appendItems(viewModels)
        dataSource?.apply(snapshot, animatingDifferences: true)
    }

    func updateReferendums(time: [UInt: StatusTimeViewModel?]) {
        guard let dataSource = self.dataSource,
              let visibleRows = rootView.tableView.indexPathsForVisibleRows else {
            return
        }

        let visibleItems = visibleRows.compactMap(dataSource.itemIdentifier).compactMap {
            switch $0.viewModel {
            case let .loaded(value):
                var updatingValue = value
                updatingValue.referendumInfo.time = time[$0.referendumIndex]??.viewModel
                return Row(
                    referendumIndex: $0.referendumIndex,
                    viewModel: .cached(value: updatingValue)
                )
            case let .cached(value):
                var updatingValue = value
                updatingValue.referendumInfo.time = time[$0.referendumIndex]??.viewModel
                return Row(
                    referendumIndex: $0.referendumIndex,
                    viewModel: .cached(value: updatingValue)
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
        dataSource.apply(newSnapshot)
    }
}
