import Foundation

protocol ChainAssetViewModelFactoryProtocol {
    func createViewModel(from chainAsset: ChainAsset) -> ChainAssetViewModel
}

final class ChainAssetViewModelFactory: ChainAssetViewModelFactoryProtocol {
    let networkViewModelFactory: NetworkViewModelFactoryProtocol

    init(networkViewModelFactory: NetworkViewModelFactoryProtocol) {
        self.networkViewModelFactory = networkViewModelFactory
    }

    func createViewModel(from chainAsset: ChainAsset) -> ChainAssetViewModel {
        let networkViewModel = networkViewModelFactory.createViewModel(from: chainAsset.chain)

        let assetIconUrl = chainAsset.asset.icon ?? chainAsset.chain.icon
        let assetIconViewModel = RemoteImageViewModel(url: assetIconUrl)

        let assetViewModel = AssetViewModel(
            symbol: chainAsset.asset.symbol,
            imageViewModel: assetIconViewModel
        )

        return ChainAssetViewModel(networkViewModel: networkViewModel, assetViewModel: assetViewModel)
    }
}
