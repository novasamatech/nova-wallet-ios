import Foundation

struct SwapTokenSelectBalanceViewModel {
    let amount: String
    let price: String?
}

struct SwapTokenSelectTokenViewModel {
    let chainAssetId: ChainAssetId
    let symbol: String
    let networkName: String
    let tokenIcon: ImageViewModelProtocol?
    let networkIcon: ImageViewModelProtocol?
    let balance: SwapTokenSelectBalanceViewModel?
    let isCurrent: Bool
    let isPending: Bool
}

enum SwapTokenSelectRowViewModel {
    case token(SwapTokenSelectTokenViewModel)
    case loading
}

struct SwapTokenSelectSectionViewModel {
    let title: String
    let rows: [SwapTokenSelectRowViewModel]
}

enum SwapTokenSelectListViewModel {
    case loading
    case empty(String)
    case sections([SwapTokenSelectSectionViewModel])
}

struct SwapTokenSelectChipViewModel {
    enum Kind: Equatable {
        case all
        case network(ChainModel.Id)
        case more
    }

    let kind: Kind
    let title: String
    let icon: ImageViewModelProtocol?
    let isSelected: Bool
}

struct SwapTokenSelectNetworkViewModel {
    let chainId: ChainModel.Id
    let network: NetworkViewModel
    let isSelected: Bool
}
