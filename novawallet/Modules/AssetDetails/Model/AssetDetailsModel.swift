import Foundation

struct AssetDetailsModel {
    let tokenName: String
    let assetIcon: ImageViewModelProtocol?
    let price: AssetPriceViewModel?
    let network: NetworkViewModel
}
