import Foundation
import CommonWallet
import SoraFoundation
import SubstrateSdk

protocol StakingUnbondConfirmViewModelFactoryProtocol {
    func createUnbondConfirmViewModel(
        controllerItem: AccountItem,
        amount: Decimal,
        shouldResetRewardDestination: Bool
    ) throws -> StakingUnbondConfirmViewModel
}

final class StakingUnbondConfirmViewModelFactory: StakingUnbondConfirmViewModelFactoryProtocol {
    let assetInfo: AssetBalanceDisplayInfo

    private lazy var formatterFactory = AssetBalanceFormatterFactory()
    private lazy var iconGenerator = PolkadotIconGenerator()

    init(assetInfo: AssetBalanceDisplayInfo) {
        self.assetInfo = assetInfo
    }

    private func createHints(from shouldResetRewardDestination: Bool)
        -> LocalizableResource<[TitleIconViewModel]> {
        LocalizableResource { locale in
            var items = [TitleIconViewModel]()

            items.append(
                TitleIconViewModel(
                    title: R.string.localizable.stakingHintNoRewards(preferredLanguages: locale.rLanguages),
                    icon: R.image.iconNoReward()
                )
            )

            if shouldResetRewardDestination {
                items.append(
                    TitleIconViewModel(
                        title: R.string.localizable.stakingHintUnbondKillsStash(
                            preferredLanguages: locale.rLanguages
                        ),
                        icon: R.image.iconWallet()
                    )
                )
            }

            items.append(
                TitleIconViewModel(
                    title: R.string.localizable.stakingHintRedeem(
                        preferredLanguages: locale.rLanguages
                    ),
                    icon: R.image.iconRedeem()
                )
            )

            return items
        }
    }

    func createUnbondConfirmViewModel(
        controllerItem: AccountItem,
        amount: Decimal,
        shouldResetRewardDestination: Bool
    ) throws -> StakingUnbondConfirmViewModel {
        let formatter = formatterFactory.createInputFormatter(for: assetInfo)

        let amount = LocalizableResource { locale in
            formatter.value(for: locale).string(from: amount as NSNumber) ?? ""
        }

        let icon = try iconGenerator.generateFromAddress(controllerItem.address)

        let hints = createHints(from: shouldResetRewardDestination)

        return StakingUnbondConfirmViewModel(
            senderAddress: controllerItem.address,
            senderIcon: icon,
            senderName: controllerItem.username,
            amount: amount,
            hints: hints
        )
    }
}
