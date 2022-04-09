import Foundation
import CommonWallet
import SoraFoundation
import SubstrateSdk

protocol StakingUnbondConfirmViewModelFactoryProtocol {
    func createUnbondConfirmViewModel(
        controllerItem: ChainAccountResponse,
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
                    title: R.string.localizable.stakingHintNoRewards_V2_2_0(
                        preferredLanguages: locale.rLanguages
                    ),
                    icon: R.image.iconStarGray16()
                )
            )

            if shouldResetRewardDestination {
                items.append(
                    TitleIconViewModel(
                        title: R.string.localizable.stakingHintUnbondKillsStash(
                            preferredLanguages: locale.rLanguages
                        ),
                        icon: R.image.iconStarGray16()
                    )
                )
            }

            items.append(
                TitleIconViewModel(
                    title: R.string.localizable.stakingHintRedeem_v2_2_0(
                        preferredLanguages: locale.rLanguages
                    ),
                    icon: R.image.iconStarGray16()
                )
            )

            return items
        }
    }

    func createUnbondConfirmViewModel(
        controllerItem: ChainAccountResponse,
        amount: Decimal,
        shouldResetRewardDestination: Bool
    ) throws -> StakingUnbondConfirmViewModel {
        let formatter = formatterFactory.createInputFormatter(for: assetInfo)

        let amount = LocalizableResource { locale in
            formatter.value(for: locale).string(from: amount as NSNumber) ?? ""
        }

        let icon = try iconGenerator.generateFromAccountId(controllerItem.accountId)

        let hints = createHints(from: shouldResetRewardDestination)

        return StakingUnbondConfirmViewModel(
            senderAddress: controllerItem.toAddress() ?? "",
            senderIcon: icon,
            senderName: controllerItem.name,
            amount: amount,
            hints: hints
        )
    }
}
