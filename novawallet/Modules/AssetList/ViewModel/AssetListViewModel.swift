import Foundation
import SubstrateSdk

enum LoadableViewModelState<T> {
    case loading
    case cached(value: T)
    case loaded(value: T)

    var isLoading: Bool {
        switch self {
        case .loading:
            return true
        case .cached, .loaded:
            return false
        }
    }

    func map<V>(with closure: (T) -> V) -> LoadableViewModelState<V> {
        switch self {
        case .loading:
            return .loading
        case let .cached(value):
            let newValue = closure(value)
            return .cached(value: newValue)
        case let .loaded(value):
            let newValue = closure(value)
            return .loaded(value: newValue)
        }
    }

    func satisfies(_ closure: (T) -> Bool) -> Bool {
        switch self {
        case .loading:
            return false
        case let .cached(value), let .loaded(value):
            return closure(value)
        }
    }
}

enum ValueDirection<T> {
    case increase(value: T)
    case decrease(value: T)
}

struct AssetListHeaderViewModel {
    let walletConnectSessionsCount: String?
    let title: String
    let amount: LoadableViewModelState<AssetListTotalAmountViewModel>
    let locksAmount: String?
    let walletSwitch: WalletSwitchViewModel
    let hasSwaps: Bool
}

struct AssetListTotalAmountViewModel {
    let amount: String
    let decimalSeparator: String?
}

struct AssetListNftsViewModel {
    let totalCount: LoadableViewModelState<String>
    let mediaViewModels: [NftMediaViewModelProtocol]
}

struct AssetPriceViewModel {
    let amount: String
    let change: ValueDirection<String>
}

enum AssetListGroupState {
    case empty
    case list(groups: [AssetListGroupType])

    var isEmpty: Bool {
        switch self {
        case .empty:
            return true
        case .list:
            return false
        }
    }

    var groups: [AssetListGroupType] {
        switch self {
        case .empty:
            return []
        case let .list(groups):
            return groups
        }
    }
}

struct AssetListViewModel {
    let isFiltered: Bool
    let listState: AssetListGroupState
}

// MARK: Group

enum AssetListGroupType: Identifiable {
    case network(AssetListNetworkGroupViewModel)
    case token(AssetListTokenGroupViewModel)

    var id: String {
        switch self {
        case let .network(model): model.id
        case let .token(model): model.id
        }
    }
}

struct AssetListNetworkGroupViewModel: Identifiable {
    var id: String { networkName }

    let networkName: String
    let amount: LoadableViewModelState<String>
    let icon: ImageViewModelProtocol?
    let assets: [AssetListNetworkGroupAssetViewModel]
}

struct AssetListTokenGroupViewModel: Identifiable {
    var id: String { token.symbol }

    let token: AssetViewModel
    let assets: [AssetListTokenGroupAssetViewModel]

    let balance: AssetListAssetBalanceViewModel
}

// MARK: Asset

struct AssetListNetworkGroupAssetViewModel: Identifiable {
    var id: String { chainAssetId.stringValue }

    let chainAssetId: ChainAssetId
    let tokenName: String
    let icon: ImageViewModelProtocol?
    let balance: AssetListAssetBalanceViewModel
}

struct AssetListTokenGroupAssetViewModel: Identifiable {
    var id: String { chainAssetId.stringValue }

    let chainAssetId: ChainAssetId
    let chainAsset: ChainAssetViewModel
    let balance: AssetListAssetBalanceViewModel
}

struct AssetListAssetBalanceViewModel {
    let price: LoadableViewModelState<AssetPriceViewModel>
    let balanceAmount: LoadableViewModelState<String>
    let balanceValue: LoadableViewModelState<String>
}

extension LoadableViewModelState: Hashable, Equatable where T == String {}
