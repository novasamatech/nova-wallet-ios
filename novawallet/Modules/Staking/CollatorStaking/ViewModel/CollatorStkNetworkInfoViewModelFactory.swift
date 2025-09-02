import Foundation
import Foundation_iOS

struct CollatorStkNetworkModel {
    let totalStake: Balance
    let minStake: Balance
    let activeDelegators: Int
    let unstakingDuration: TimeInterval?
}

protocol CollatorStkNetworkInfoViewModelFactoryProtocol {
    func createViewModel(
        from model: CollatorStkNetworkModel,
        chainAsset: ChainAsset,
        price: PriceData?,
        locale: Locale
    ) -> NetworkStakingInfoViewModel
}

final class CollatorStkNetworkInfoViewModelFactory: CollatorStkNetworkInfoViewModelFactoryProtocol {
    private let priceAssetInfoFactory: PriceAssetInfoFactoryProtocol

    init(priceAssetInfoFactory: PriceAssetInfoFactoryProtocol) {
        self.priceAssetInfoFactory = priceAssetInfoFactory
    }

    private func createStakeViewModel(
        stake: Balance,
        displayInfo: AssetBalanceDisplayInfo,
        priceData: PriceData?,
        balanceViewModelFactory: BalanceViewModelFactoryProtocol
    ) -> LocalizableResource<BalanceViewModelProtocol> {
        let stakedAmount = Decimal.fromSubstrateAmount(
            stake,
            precision: displayInfo.assetPrecision
        ) ?? 0.0

        let stakedPair = balanceViewModelFactory.balanceFromPrice(
            stakedAmount,
            priceData: priceData
        )

        return LocalizableResource { locale in
            stakedPair.value(for: locale)
        }
    }

    private func createTotalStakeViewModel(
        with networkInfo: CollatorStkNetworkModel,
        displayInfo: AssetBalanceDisplayInfo,
        priceData: PriceData?,
        balanceViewModelFactory: BalanceViewModelFactoryProtocol
    ) -> LocalizableResource<BalanceViewModelProtocol> {
        createStakeViewModel(
            stake: networkInfo.totalStake,
            displayInfo: displayInfo,
            priceData: priceData,
            balanceViewModelFactory: balanceViewModelFactory
        )
    }

    private func createMinimalStakeViewModel(
        with networkInfo: CollatorStkNetworkModel,
        displayInfo: AssetBalanceDisplayInfo,
        priceData: PriceData?,
        balanceViewModelFactory: BalanceViewModelFactoryProtocol
    ) -> LocalizableResource<BalanceViewModelProtocol> {
        createStakeViewModel(
            stake: networkInfo.minStake,
            displayInfo: displayInfo,
            priceData: priceData,
            balanceViewModelFactory: balanceViewModelFactory
        )
    }

    private func createActiveNominatorsViewModel(
        with networkInfo: CollatorStkNetworkModel
    ) -> LocalizableResource<String> {
        let formatter = NumberFormatter.quantity.localizableResource()

        return LocalizableResource { locale in
            formatter.value(for: locale).string(
                from: networkInfo.activeDelegators as NSNumber
            ) ?? ""
        }
    }

    private func createUnstakingPeriodViewModel(
        unstakingDuration: TimeInterval?
    ) -> LocalizableResource<String> {
        if let unstakingDuration {
            return LocalizableResource { locale in
                let formattedString = unstakingDuration.localizedDaysHoursOrFallbackMinutes(for: locale)
                return "~\(formattedString)"
            }
        } else {
            return LocalizableResource { _ in "" }
        }
    }

    func createViewModel(
        from model: CollatorStkNetworkModel,
        chainAsset: ChainAsset,
        price: PriceData?,
        locale: Locale
    ) -> NetworkStakingInfoViewModel {
        let assetDisplayInfo = chainAsset.assetDisplayInfo
        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: assetDisplayInfo,
            priceAssetInfoFactory: priceAssetInfoFactory
        )

        let totalStake = createTotalStakeViewModel(
            with: model,
            displayInfo: assetDisplayInfo,
            priceData: price,
            balanceViewModelFactory: balanceViewModelFactory
        ).value(for: locale)

        let minimalStake = createMinimalStakeViewModel(
            with: model,
            displayInfo: assetDisplayInfo,
            priceData: price,
            balanceViewModelFactory: balanceViewModelFactory
        ).value(for: locale)

        let nominatorsCount = createActiveNominatorsViewModel(with: model).value(for: locale)

        let unstakingPeriod = createUnstakingPeriodViewModel(
            unstakingDuration: model.unstakingDuration
        ).value(for: locale)

        let stakingPeriod = R.string.localizable.stakingNetworkInfoStakingPeriodValue(
            preferredLanguages: locale.rLanguages
        )

        return .init(
            totalStake: .loaded(value: totalStake),
            minimalStake: .loaded(value: minimalStake),
            activeNominators: .loaded(value: nominatorsCount),
            stakingPeriod: .loaded(value: stakingPeriod),
            lockUpPeriod: .loaded(value: unstakingPeriod)
        )
    }
}
