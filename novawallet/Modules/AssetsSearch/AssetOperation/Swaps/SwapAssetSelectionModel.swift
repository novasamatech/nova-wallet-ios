import Foundation

enum SwapAssetSelectionModel {
    case payForAsset(ChainAsset?)
    case receivePayingWith(ChainAsset?)
}

extension SwapAssetSelectionModel {
    var includesHiddenAssets: Bool {
        switch self {
        case .payForAsset: false
        case .receivePayingWith: true
        }
    }
}
