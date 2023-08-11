import SoraFoundation

protocol StakingSelectPoolViewModelFactoryProtocol: StakingSelectPoolViewModelFactory {
    func createStakingSelectPoolViewModels(
        from poolStats: [NominationPools.PoolStats],
        chainAsset: ChainAsset,
        locale: Locale
    ) -> [StakingSelectPoolViewModel]
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

    func createStakingSelectPoolViewModels(
        from poolStats: [NominationPools.PoolStats],
        chainAsset: ChainAsset,
        locale: Locale
    ) -> [StakingSelectPoolViewModel] {
        poolStats.map {
            let selectedPool = NominationPools.SelectedPool(poolStats: $0)
            let title = selectedPool.title(for: chainAsset.chain.chainFormat) ?? ""
            let apy = selectedPool.maxApy.map {
                apyFormatter.value(for: locale).stringFromDecimal($0)
            } ?? nil
            let period = R.string.localizable.commonPerYear(preferredLanguages: locale.rLanguages)
            let members = membersFormatter.value(for: locale).string(from: .init(value: $0.membersCount)) ?? ""
            let imageViewModel = poolIconFactory.createIconViewModel(
                for: chainAsset,
                poolId: $0.poolId,
                bondedAccountId: $0.bondedAccountId
            )
            return StakingSelectPoolViewModel(
                imageViewModel: imageViewModel,
                name: title,
                apy: apy.map { .init(value: $0, period: period) },
                members: members,
                id: $0.poolId
            )
        }
    }
}
