import SoraFoundation

struct SwapsAssetViewModel {
    let symbol: String
    let imageViewModel: ImageViewModelProtocol?
    let hub: NetworkViewModel
}

struct EmptySwapsAssetViewModel {
    let imageViewModel: ImageViewModelProtocol?
    let title: String
    let subtitle: String
}

enum SwapAssetInputViewModel {
    case asset(SwapsAssetViewModel)
    case empty(EmptySwapsAssetViewModel)
}

struct SwapFeeViewModel {
    var isEditable: Bool
    var balanceViewModel: BalanceViewModelProtocol
}

struct SwapPriceDifferenceViewModel {
    let price: String?
    let difference: DifferenceViewModel?
}

struct SwapSetupFeeIdentifier: Equatable {
    let transactionId: String
    let feeChainAssetId: ChainAssetId?
}

enum FeeSelectionViewModel: Int, CaseIterable {
    case payAsset
    case utilityAsset
}

extension FeeSelectionViewModel {
    static var title = LocalizableResource {
        R.string.localizable.commonNetworkFee(
            preferredLanguages: $0.rLanguages
        )
    }

    static var message = LocalizableResource {
        R.string.localizable.swapsSetupNetworkFeeTokenTitle(
            preferredLanguages: $0.rLanguages
        )
    }

    static var hint = LocalizableResource {
        R.string.localizable.swapsSetupNetworkFeeTokenHint(
            preferredLanguages: $0.rLanguages
        )
    }
}
