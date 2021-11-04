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

struct WalletPriceViewModel {
    let amount: String
    let change: ValueDirection<String>
}

struct WalletListViewModel {
    let networkName: String
    let tokenName: String
    let icon: ImageViewModelProtocol?
    let price: LoadableViewModelState<WalletPriceViewModel>
    let balanceAmount: LoadableViewModelState<String>
    let balanceValue: LoadableViewModelState<String>
}
