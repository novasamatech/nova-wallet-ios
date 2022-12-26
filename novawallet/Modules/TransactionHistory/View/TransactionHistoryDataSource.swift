import UIKit

final class TransactionHistoryDataSource: UITableViewDiffableDataSource<TransactionSectionModel, TransactionItemViewModel> {
    init(tableView: UITableView) {
        super.init(tableView: tableView) { tableView, indexPath, viewModel in
            let cell: HistoryItemTableViewCell = tableView.dequeueReusableCell(for: indexPath)
            cell.bind(transactionModel: viewModel)
            return cell
        }
        defaultRowAnimation = .bottom
    }
}
