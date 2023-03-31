import Foundation
import CommonWallet

final class HistoryItemViewModel: WalletViewModelProtocol {
    enum TextType {
        case rawString
        case address
    }

    var cellReuseIdentifier: String { HistoryConstants.historyCellId }
    var itemHeight: CGFloat { HistoryConstants.historyHeight }

    let title: String
    let subtitle: String
    let time: String
    let amount: String
    let type: TransactionType
    let status: AssetTransactionStatus
    let titleType: TextType
    let imageViewModel: ImageViewModelProtocol?
    let command: WalletCommandProtocol?

    init(
        title: String,
        subtitle: String,
        amount: String,
        time: String,
        type: TransactionType,
        status: AssetTransactionStatus,
        imageViewModel: ImageViewModelProtocol?,
        command: WalletCommandProtocol?,
        titleType: TextType = .rawString
    ) {
        self.title = title
        self.subtitle = subtitle
        self.amount = amount
        self.time = time
        self.type = type
        self.status = status
        self.titleType = titleType
        self.imageViewModel = imageViewModel
        self.command = command
    }
}
