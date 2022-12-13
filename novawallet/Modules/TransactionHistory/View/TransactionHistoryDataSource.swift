import UIKit

final class TransactionHistoryDataSource: UITableViewDiffableDataSource<TransactionSectionModel, TransactionItemViewModel> {
    init(tableView: UITableView) {
        super.init(tableView: tableView) { tableView, indexPath, viewModel in
            let cell: HistoryItemTableViewCell = tableView.dequeueReusableCell(for: indexPath)
            cell.bind(transactionModel: viewModel)
            return cell
        }
    }

    func tableView(_: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let headerView: TransactionHistoryHeaderView = .init(frame: .zero)
        headerView.bind(title: snapshot().sectionIdentifiers[section].title)

        return headerView
    }
}
