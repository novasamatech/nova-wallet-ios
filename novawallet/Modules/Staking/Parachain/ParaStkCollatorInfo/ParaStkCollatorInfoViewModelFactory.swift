import Foundation
import SubstrateSdk
import SoraFoundation
import CommonWallet

protocol ParaStkCollatorInfoViewModelFactoryProtocol {
    func createStakingAmountsViewModel(
        from collatorInfo: CollatorSelectionInfo,
        priceData: PriceData?
    ) -> [LocalizableResource<StakingAmountViewModel>]

    func createViewModel(
        for selectedAccountId: AccountId,
        collatorInfo: CollatorSelectionInfo,
        priceData: PriceData?,
        locale: Locale
    ) throws -> ValidatorInfoViewModel
}

final class ParaStkCollatorInfoViewModelFactory: BaseValidatorInfoViewModelFactory {
    private let balanceViewModelFactory: BalanceViewModelFactoryProtocol

    private lazy var iconGenerator = PolkadotIconGenerator()

    let precision: Int16
    let chainFormat: ChainFormat

    init(
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        precision: Int16,
        chainFormat: ChainFormat
    ) {
        self.balanceViewModelFactory = balanceViewModelFactory
        self.precision = precision
        self.chainFormat = chainFormat
    }

    private func createMinimumStakeViewModel(
        from collatorInfo: CollatorSelectionInfo,
        price: PriceData?,
        locale: Locale
    ) -> BalanceViewModelProtocol {
        let amount = Decimal.fromSubstrateAmount(collatorInfo.minRewardableStake, precision: precision) ?? 0

        return balanceViewModelFactory.balanceFromPrice(amount, priceData: price).value(for: locale)
    }

    private func createExposure(
        for selectedAccountId: AccountId,
        collatorInfo: CollatorSelectionInfo,
        priceData: PriceData?,
        locale: Locale
    ) -> ValidatorInfoViewModel.Exposure {
        let formatter = NumberFormatter.quantity.localizableResource().value(for: locale)

        let delegatorsCount = collatorInfo.metadata.delegationCount

        let nominators = formatter.string(from: NSNumber(value: delegatorsCount)) ?? ""

        let maxNominatorsRewardedString = R.string.localizable.stakingMaxNominatorRewardedFormat(
            formatter.string(from: NSNumber(value: collatorInfo.maxRewardedDelegations)) ?? "",
            preferredLanguages: locale.rLanguages
        )

        let myNomination: ValidatorInfoViewModel.MyNomination?

        if let snapshot = collatorInfo.snapshot {
            let isRewarded = snapshot.delegations.contains { $0.owner == selectedAccountId }
            myNomination = ValidatorInfoViewModel.MyNomination(isRewarded: isRewarded)
        } else {
            myNomination = nil
        }

        let totalStakeDecimal = Decimal.fromSubstrateAmount(collatorInfo.totalStake, precision: precision) ?? 0

        let totalStake = balanceViewModelFactory.balanceFromPrice(
            totalStakeDecimal,
            priceData: priceData
        ).value(for: locale)

        let estimatedReward = collatorInfo.apr.flatMap {
            NumberFormatter.percentAPR.localizableResource().value(for: locale).stringFromDecimal($0)
        } ?? ""

        let minStake = createMinimumStakeViewModel(from: collatorInfo, price: priceData, locale: locale)

        return ValidatorInfoViewModel.Exposure(
            nominators: nominators,
            maxNominators: maxNominatorsRewardedString,
            myNomination: myNomination,
            totalStake: totalStake,
            minRewardableStake: minStake,
            estimatedReward: estimatedReward,
            oversubscribed: false
        )
    }

    private func createOwnStakeTitle() -> LocalizableResource<String> {
        LocalizableResource { locale in
            R.string.localizable.stakingValidatorOwnStake(preferredLanguages: locale.rLanguages)
        }
    }

    private func createDelegatorsStakeTitle() -> LocalizableResource<String> {
        LocalizableResource { locale in
            R.string.localizable.commonParastkDelegators(preferredLanguages: locale.rLanguages)
        }
    }

    private func createTotalTitle() -> LocalizableResource<String> {
        LocalizableResource { locale in
            R.string.localizable.walletTransferTotalTitle(preferredLanguages: locale.rLanguages)
        }
    }

    private func createStakingAmountRow(
        title: LocalizableResource<String>,
        amount: Decimal,
        priceData: PriceData?
    ) -> LocalizableResource<StakingAmountViewModel> {
        let balance = balanceViewModelFactory.balanceFromPrice(amount, priceData: priceData)

        return LocalizableResource { locale in

            let title = title.value(for: locale)

            return StakingAmountViewModel(
                title: title,
                balance: balance.value(for: locale)
            )
        }
    }
}

extension ParaStkCollatorInfoViewModelFactory: ParaStkCollatorInfoViewModelFactoryProtocol {
    func createViewModel(
        for selectedAccountId: AccountId,
        collatorInfo: CollatorSelectionInfo,
        priceData: PriceData?,
        locale: Locale
    ) throws -> ValidatorInfoViewModel {
        let address = try collatorInfo.accountId.toAddress(using: chainFormat)
        let iconViewModel = try iconGenerator.generateFromAccountId(collatorInfo.accountId)
        let accountViewModel = WalletAccountViewModel(
            walletName: collatorInfo.identity?.displayName,
            walletIcon: nil,
            address: address,
            addressIcon: DrawableIconViewModel(icon: iconViewModel)
        )

        let status: ValidatorInfoViewModel.StakingStatus

        if collatorInfo.snapshot != nil {
            let exposure = createExposure(
                for: selectedAccountId,
                collatorInfo: collatorInfo,
                priceData: priceData,
                locale: locale
            )

            status = .elected(exposure: exposure)
        } else {
            status = .unelected
        }

        let staking = ValidatorInfoViewModel.Staking(
            status: status,
            slashed: false
        )

        let identityItems = collatorInfo.identity.map { identity in
            createIdentityViewModel(from: identity, locale: locale)
        }

        return ValidatorInfoViewModel(
            account: accountViewModel,
            staking: staking,
            identity: identityItems
        )
    }

    func createStakingAmountsViewModel(
        from collatorInfo: CollatorSelectionInfo,
        priceData: PriceData?
    ) -> [LocalizableResource<StakingAmountViewModel>] {
        let ownStake = Decimal.fromSubstrateAmount(collatorInfo.ownStake, precision: precision) ?? 0
        let delegatorsStake = Decimal.fromSubstrateAmount(collatorInfo.delegatorsStake, precision: precision) ?? 0
        let totalStake = Decimal.fromSubstrateAmount(collatorInfo.totalStake, precision: precision) ?? 0

        return [
            createStakingAmountRow(
                title: createOwnStakeTitle(),
                amount: ownStake,
                priceData: priceData
            ),
            createStakingAmountRow(
                title: createDelegatorsStakeTitle(),
                amount: delegatorsStake,
                priceData: priceData
            ),
            createStakingAmountRow(
                title: createTotalTitle(),
                amount: totalStake,
                priceData: priceData
            )
        ]
    }
}
