import Foundation
import Foundation_iOS
import BigInt

protocol ParaStkNetworkInfoViewModelFactoryProtocol {
    func createViewModel(
        from model: ParachainStaking.NetworkInfo,
        duration: ParachainStakingDuration?,
        chainAsset: ChainAsset,
        price: PriceData?,
        locale: Locale
    ) -> NetworkStakingInfoViewModel
}

extension ParachainStaking {
    final class NetworkInfoViewModelFactory: ParaStkNetworkInfoViewModelFactoryProtocol {
        private let priceAssetInfoFactory: PriceAssetInfoFactoryProtocol

        init(priceAssetInfoFactory: PriceAssetInfoFactoryProtocol) {
            self.priceAssetInfoFactory = priceAssetInfoFactory
        }

        private func createStakeViewModel(
            stake: BigUInt,
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
            with networkInfo: ParachainStaking.NetworkInfo,
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
            with networkInfo: ParachainStaking.NetworkInfo,
            displayInfo: AssetBalanceDisplayInfo,
            priceData: PriceData?,
            balanceViewModelFactory: BalanceViewModelFactoryProtocol
        ) -> LocalizableResource<BalanceViewModelProtocol> {
            let minStake = max(networkInfo.minStakeForRewards, networkInfo.minTechStake)
            return createStakeViewModel(
                stake: minStake,
                displayInfo: displayInfo,
                priceData: priceData,
                balanceViewModelFactory: balanceViewModelFactory
            )
        }

        private func createActiveNominatorsViewModel(
            with networkInfo: ParachainStaking.NetworkInfo
        ) -> LocalizableResource<String> {
            let formatter = NumberFormatter.quantity.localizableResource()

            return LocalizableResource { locale in
                formatter.value(for: locale).string(
                    from: networkInfo.activeDelegatorsCount as NSNumber
                ) ?? ""
            }
        }

        private func createUnstakingPeriodViewModel(
            duration: ParachainStakingDuration?
        ) -> LocalizableResource<String> {
            if let unstaking = duration?.unstaking {
                return LocalizableResource { locale in
                    let formattedString = unstaking.localizedDaysHours(for: locale)
                    return "~\(formattedString)"
                }
            } else {
                return LocalizableResource { _ in "" }
            }
        }

        func createViewModel(
            from model: ParachainStaking.NetworkInfo,
            duration: ParachainStakingDuration?,
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
                duration: duration
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
}
