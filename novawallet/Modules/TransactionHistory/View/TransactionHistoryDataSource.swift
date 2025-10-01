import UIKit

final class TransactionHistoryDataSource: UITableViewDiffableDataSource<
    TransactionHistorySectionModel, TransactionHistoryItemModel
> {
    init(tableView: UITableView) {
        super.init(tableView: tableView) { tableView, indexPath, viewModel in
            switch viewModel {
            case let .ahmHint(ahmHintModel):
                let cell: HistoryAHMTableViewCell = tableView.dequeueReusableCell(for: indexPath)
                cell.bind(ahmHintModel)
                return cell
            case let .transaction(transactionModel):
                let cell: HistoryItemTableViewCell = tableView.dequeueReusableCell(for: indexPath)
                cell.bind(transactionModel: transactionModel)
                return cell
            }
        }
        defaultRowAnimation = .fade
    }
}
