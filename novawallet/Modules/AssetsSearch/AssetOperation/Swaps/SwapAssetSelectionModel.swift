import Foundation

enum SwapAssetSelectionModel {
    case payForAsset(ChainAsset?)
    case receivePayingWith(ChainAsset?)
}
