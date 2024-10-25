import Foundation

protocol ChainAssetViewModelFactoryProtocol {
    func createViewModel(from chainAsset: ChainAsset) -> ChainAssetViewModel
    func createIdentifiableViewModel(from chainAsset: ChainAsset) -> IdentifiableChainAssetViewModel
}

final class ChainAssetViewModelFactory: ChainAssetViewModelFactoryProtocol {
    let networkViewModelFactory: NetworkViewModelFactoryProtocol

    init(networkViewModelFactory: NetworkViewModelFactoryProtocol = NetworkViewModelFactory()) {
        self.networkViewModelFactory = networkViewModelFactory
    }

    func createViewModel(from chainAsset: ChainAsset) -> ChainAssetViewModel {
        let networkViewModel = networkViewModelFactory.createViewModel(from: chainAsset.chain)

        let assetIconViewModel = ImageViewModelFactory.createAssetIconOrDefault(from: chainAsset.asset.icon)
        let assetViewModel = AssetViewModel(symbol: chainAsset.asset.symbol, imageViewModel: assetIconViewModel)

        return ChainAssetViewModel(networkViewModel: networkViewModel, assetViewModel: assetViewModel)
    }

    func createIdentifiableViewModel(from chainAsset: ChainAsset) -> IdentifiableChainAssetViewModel {
        let viewModel = createViewModel(from: chainAsset)

        return IdentifiableChainAssetViewModel(
            chainAssetId: chainAsset.chainAssetId,
            viewModel: viewModel
        )
    }
}
