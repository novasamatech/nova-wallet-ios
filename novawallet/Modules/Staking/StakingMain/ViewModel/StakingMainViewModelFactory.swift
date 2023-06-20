import Foundation
import BigInt

protocol StakingMainViewModelFactoryProtocol {
    func createMainViewModel(
        chainAsset: ChainAsset
    ) -> StakingMainViewModel
}

final class StakingMainViewModelFactory: StakingMainViewModelFactoryProtocol {
    func createMainViewModel(chainAsset: ChainAsset) -> StakingMainViewModel {
        StakingMainViewModel(chainName: chainAsset.chain.name)
    }
}
