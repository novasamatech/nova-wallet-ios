import Foundation
import Foundation_iOS

protocol StakingSelectPoolViewModelFactoryProtocol {
    func createStakingSelectPoolViewModel(
        from poolStats: NominationPools.PoolStats,
        selectedPoolId: NominationPools.PoolId?,
        chainAsset: ChainAsset,
        locale: Locale
    ) -> StakingSelectPoolViewModel
}

final class StakingSelectPoolViewModelFactory: StakingSelectPoolViewModelFactoryProtocol {
    let apyFormatter: LocalizableResource<NumberFormatter>
    let membersFormatter: LocalizableResource<NumberFormatter>
    let poolIconFactory: NominationPoolsIconFactoryProtocol

    init(
        apyFormatter: LocalizableResource<NumberFormatter>,
        membersFormatter: LocalizableResource<NumberFormatter>,
        poolIconFactory: NominationPoolsIconFactoryProtocol
    ) {
        self.apyFormatter = apyFormatter
        self.membersFormatter = membersFormatter
        self.poolIconFactory = poolIconFactory
    }

    func createStakingSelectPoolViewModel(
        from poolStats: NominationPools.PoolStats,
        selectedPoolId: NominationPools.PoolId?,
        chainAsset: ChainAsset,
        locale: Locale
    ) -> StakingSelectPoolViewModel {
        let selectedPool = NominationPools.SelectedPool(poolStats: poolStats)
        let title = selectedPool.title(for: chainAsset.chain.chainFormat) ?? ""
        let apy = selectedPool.maxApy.map {
            apyFormatter.value(for: locale).stringFromDecimal($0)
        } ?? nil
        let period = R.string(preferredLanguages: locale.rLanguages).localizable.commonPerYear()
        let members = membersFormatter.value(for: locale).string(from: .init(value: poolStats.membersCount)) ?? ""
        let imageViewModel = selectedPoolId != poolStats.poolId ? poolIconFactory.createIconViewModel(
            for: chainAsset,
            poolId: poolStats.poolId,
            bondedAccountId: poolStats.bondedAccountId
        ) : StaticImageViewModel(image: R.image.iconCheckbox()!)

        return StakingSelectPoolViewModel(
            imageViewModel: imageViewModel,
            name: title,
            apy: apy.map { .init(value: $0, period: period) },
            members: members,
            id: poolStats.poolId
        )
    }
}

extension StakingSelectPoolViewModelFactoryProtocol {
    func createStakingSelectPoolViewModels(
        from poolStats: [NominationPools.PoolStats],
        selectedPoolId: NominationPools.PoolId?,
        chainAsset: ChainAsset,
        locale: Locale
    ) -> [StakingSelectPoolViewModel] {
        poolStats.map {
            createStakingSelectPoolViewModel(
                from: $0,
                selectedPoolId: selectedPoolId,
                chainAsset: chainAsset,
                locale: locale
            )
        }
    }
}
