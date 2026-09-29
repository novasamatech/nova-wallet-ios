import Foundation

enum SubtensorOperationResultViewModel {
    case page(SubtensorResultPageViewModel)
    case sheet(SubtensorResultSheetViewModel)
}

struct SubtensorResultActionViewModel: Equatable {
    let action: SubtensorResultAction
    let title: String
}

enum SubtensorResultStatus: Equatable {
    case progress
    case done
    case failed
    case pending
}

struct SubtensorResultStatusViewModel {
    let status: SubtensorResultStatus
    let countdown: CountdownLoadingView.ViewModel?
    let title: String
    let subtitle: String
    let details: String
}

struct SubtensorResultDetailsViewModel {
    let title: String
    let swapRate: String
    let slippage: String?
    let validator: String
    let networkFee: BalanceViewModelProtocol?
    let isExpanded: Bool
}

struct SubtensorResultPageViewModel {
    let status: SubtensorResultStatusViewModel
    let payTile: SwapAssetAmountViewModel
    let receiveTile: SwapAssetAmountViewModel
    let details: SubtensorResultDetailsViewModel
    let action: SubtensorResultActionViewModel?
    let showsBack: Bool
}

struct SubtensorResultSheetRowViewModel {
    let title: String
    let value: String
    let fiat: String?
}

struct SubtensorResultSheetViewModel {
    let status: SubtensorResultStatus
    let title: String
    let message: String
    let rows: [SubtensorResultSheetRowViewModel]
    let reason: String?
    let actions: [SubtensorResultActionViewModel]
}
