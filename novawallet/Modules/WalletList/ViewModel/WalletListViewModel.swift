import Foundation
import SubstrateSdk

enum LoadableViewModelState<T> {
    case loading
    case cached(value: T)
    case loaded(value: T)
}

enum ValueDirection<T> {
    case increase(value: T)
    case decrease(value: T)
}

struct WalletListHeaderViewModel {
    let title: String
    let amount: LoadableViewModelState<String>
    let icon: DrawableIcon?
}

struct WalletListNftsViewModel {
    let totalCount: LoadableViewModelState<String>
    let mediaViewModels: [NftMediaViewModelProtocol]
}

struct WalletPriceViewModel {
    let amount: String
    let change: ValueDirection<String>
}

enum WalletListGroupState {
    case empty
    case list(groups: [WalletListGroupViewModel])

    var isEmpty: Bool {
        switch self {
        case .empty:
            return true
        case .list:
            return false
        }
    }

    var groups: [WalletListGroupViewModel] {
        switch self {
        case .empty:
            return []
        case let .list(groups):
            return groups
        }
    }
}

struct WalletListGroupViewModel {
    let networkName: String
    let amount: LoadableViewModelState<String>
    let icon: ImageViewModelProtocol?
    let color: GradientModel
    let assets: [WalletListAssetViewModel]
}

struct WalletListAssetViewModel {
    let chainAssetId: ChainAssetId
    let tokenName: String
    let icon: ImageViewModelProtocol?
    let price: LoadableViewModelState<WalletPriceViewModel>
    let balanceAmount: LoadableViewModelState<String>
    let balanceValue: LoadableViewModelState<String>
}
