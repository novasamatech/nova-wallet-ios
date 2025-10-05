import UIKit

enum TransactionHistorySectionModel: Hashable {
    case ahmHint(TransactionHistoryItemModel)
    case transaction(TransactionSectionModel)
}

enum TransactionHistoryItemModel: Hashable {
    case ahmHint(HistoryAHMViewModel)
    case transaction(TransactionItemViewModel)
}

struct TransactionSectionModel: Hashable {
    let title: String
    let date: Date
    let items: [TransactionHistoryItemModel]
}

struct TransactionItemViewModel: Hashable {
    static func == (lhs: TransactionItemViewModel, rhs: TransactionItemViewModel) -> Bool {
        lhs.identifier == rhs.identifier &&
            lhs.timestamp == rhs.timestamp &&
            lhs.title == rhs.title &&
            lhs.subtitle == rhs.subtitle &&
            lhs.amountDetails == rhs.amountDetails &&
            lhs.amount == rhs.amount &&
            lhs.typeViewModel.type == rhs.typeViewModel.type &&
            lhs.status == rhs.status
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(identifier)
        hasher.combine(typeViewModel.type)
    }

    let identifier: String
    let timestamp: Int64
    let title: String
    let subtitle: String
    let amount: String
    let amountDetails: String
    let typeViewModel: TransactionTypeViewModel
    let status: TransactionHistoryItem.Status
    let imageViewModel: ImageViewModelProtocol?
}

struct TransactionTypeViewModel {
    let type: TransactionType
    let isIncome: Bool

    init(_ type: TransactionType, isIncome: Bool? = nil) {
        self.type = type
        self.isIncome = isIncome ?? TransactionTypeViewModel.incomeDefault(for: type)
    }

    static func incomeDefault(for type: TransactionType) -> Bool {
        switch type {
        case .incoming, .reward, .poolReward:
            return true
        case .outgoing, .slash, .poolSlash, .extrinsic:
            return false
        case .swap:
            return false
        }
    }
}
