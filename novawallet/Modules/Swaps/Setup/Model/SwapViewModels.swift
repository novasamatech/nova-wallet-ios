import Foundation_iOS

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

enum TextFieldFocus {
    case payAsset
    case receiveAsset
}

struct SwapPriceDifferenceViewModel {
    let price: String?
    let difference: DifferenceViewModel?
}

enum FeeSelectionViewModel: Int, CaseIterable {
    case utilityAsset
    case payAsset
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
