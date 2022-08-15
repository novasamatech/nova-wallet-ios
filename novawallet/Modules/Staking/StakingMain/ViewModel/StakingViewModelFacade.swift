import Foundation
import SoraKeystore

protocol StakingViewModelFacadeProtocol {
    func createBalanceViewModelFactory(
        for chainAsset: ChainAsset,
        priceAssetInfoFactory: PriceAssetInfoFactoryProtocol
    ) -> BalanceViewModelFactoryProtocol
}

final class StakingViewModelFacade: StakingViewModelFacadeProtocol {
    func createBalanceViewModelFactory(
        for chainAsset: ChainAsset,
        priceAssetInfoFactory: PriceAssetInfoFactoryProtocol
    ) -> BalanceViewModelFactoryProtocol {
        BalanceViewModelFactory(
            targetAssetInfo: chainAsset.assetDisplayInfo,
            priceAssetInfoFactory: priceAssetInfoFactory
        )
    }
}
