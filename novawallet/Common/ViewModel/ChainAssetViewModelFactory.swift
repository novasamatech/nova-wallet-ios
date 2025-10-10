import Foundation

protocol ChainAssetViewModelFactoryProtocol {
    func createViewModel(from chainAsset: ChainAsset) -> ChainAssetViewModel
}

final class ChainAssetViewModelFactory: ChainAssetViewModelFactoryProtocol {
    let networkViewModelFactory: NetworkViewModelFactoryProtocol
    let assetIconViewModelFactory: AssetIconViewModelFactoryProtocol

    init(
        networkViewModelFactory: NetworkViewModelFactoryProtocol = NetworkViewModelFactory(),
        assetIconViewModelFactory: AssetIconViewModelFactoryProtocol = AssetIconViewModelFactory()
    ) {
        self.networkViewModelFactory = networkViewModelFactory
        self.assetIconViewModelFactory = assetIconViewModelFactory
    }

    func createViewModel(from chainAsset: ChainAsset) -> ChainAssetViewModel {
        let networkViewModel = networkViewModelFactory.createViewModel(from: chainAsset.chain)

        let assetIconViewModel = assetIconViewModelFactory.createAssetIconViewModel(
            for: chainAsset.asset.icon
        )
        let assetViewModel = AssetViewModel(
            symbol: chainAsset.asset.symbol,
            name: chainAsset.asset.name,
            imageViewModel: assetIconViewModel
        )

        return ChainAssetViewModel(
            chainAssetId: chainAsset.chainAssetId,
            networkViewModel: networkViewModel,
            assetViewModel: assetViewModel
        )
    }
}
