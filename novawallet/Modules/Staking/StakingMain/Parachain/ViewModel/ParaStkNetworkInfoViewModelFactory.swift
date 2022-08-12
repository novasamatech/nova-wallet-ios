import Foundation
import SoraFoundation
import BigInt

protocol ParaStkNetworkInfoViewModelFactoryProtocol {
    func createViewModel(
        from model: ParachainStaking.NetworkInfo,
        duration: ParachainStakingDuration?,
        chainAsset: ChainAsset,
        price: PriceData?
    ) -> LocalizableResource<NetworkStakingInfoViewModel>
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
            price: PriceData?
        ) -> LocalizableResource<NetworkStakingInfoViewModel> {
            let assetDisplayInfo = chainAsset.assetDisplayInfo
            let balanceViewModelFactory = BalanceViewModelFactory(
                targetAssetInfo: assetDisplayInfo,
                priceAssetInfoFactory: priceAssetInfoFactory
            )

            let localizedTotalStake = createTotalStakeViewModel(
                with: model,
                displayInfo: assetDisplayInfo,
                priceData: price,
                balanceViewModelFactory: balanceViewModelFactory
            )

            let localizedMinimalStake = createMinimalStakeViewModel(
                with: model,
                displayInfo: assetDisplayInfo,
                priceData: price,
                balanceViewModelFactory: balanceViewModelFactory
            )

            let nominatorsCount = createActiveNominatorsViewModel(with: model)

            let localizedUnstakingPeriod = createUnstakingPeriodViewModel(
                duration: duration
            )

            return LocalizableResource { locale in
                let stakingPeriod = R.string.localizable.stakingNetworkInfoStakingPeriodValue(
                    preferredLanguages: locale.rLanguages
                )

                return NetworkStakingInfoViewModel(
                    totalStake: localizedTotalStake.value(for: locale),
                    minimalStake: localizedMinimalStake.value(for: locale),
                    activeNominators: nominatorsCount.value(for: locale),
                    stakingPeriod: stakingPeriod,
                    lockUpPeriod: localizedUnstakingPeriod.value(for: locale)
                )
            }
        }
    }
}
