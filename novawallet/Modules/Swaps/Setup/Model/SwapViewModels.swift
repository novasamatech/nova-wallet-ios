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
        R.string(preferredLanguages: $0.rLanguages
        ).localizable.commonNetworkFee()
    }

    static var message = LocalizableResource {
        R.string(preferredLanguages: $0.rLanguages
        ).localizable.swapsSetupNetworkFeeTokenTitle()
    }

    static var hint = LocalizableResource {
        R.string(preferredLanguages: $0.rLanguages
        ).localizable.swapsSetupNetworkFeeTokenHint()
    }
}
