import UIKit
import Foundation
import SubstrateSdk

protocol NominationPoolsIconFactoryProtocol {
    func createIconViewModel(
        for chainAsset: ChainAsset,
        poolId: NominationPools.PoolId,
        bondedAccountId: AccountId
    ) -> ImageViewModelProtocol?
}

final class NominationPoolsIconFactory {
    private lazy var iconGenerator = PolkadotIconGenerator()

    private func getKnownPoolIcon(for chainAsset: ChainAsset, poolId: NominationPools.PoolId) -> UIImage? {
        let chainId = chainAsset.chain.chainId
        let isKnownPool = StakingConstants.recommendedPoolIds[chainId] == poolId

        return isKnownPool ? R.image.iconNova() : nil
    }
}

extension NominationPoolsIconFactory: NominationPoolsIconFactoryProtocol {
    func createIconViewModel(
        for chainAsset: ChainAsset,
        poolId: NominationPools.PoolId,
        bondedAccountId: AccountId
    ) -> ImageViewModelProtocol? {
        if let knownPoolIcon = getKnownPoolIcon(for: chainAsset, poolId: poolId) {
            return StaticImageViewModel(image: knownPoolIcon)
        }

        guard let accountIcon = try? iconGenerator.generateFromAccountId(bondedAccountId) else {
            return nil
        }

        return DrawableIconViewModel(icon: accountIcon)
    }
}
