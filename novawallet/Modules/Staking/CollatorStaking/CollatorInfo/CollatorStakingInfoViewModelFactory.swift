import Foundation
import SubstrateSdk
import Foundation_iOS

protocol CollatorStakingInfoViewModelFactoryProtocol {
    func createStakingAmountsViewModel(
        from collatorInfo: CollatorStakingSelectionInfoProtocol,
        priceData: PriceData?
    ) -> [LocalizableResource<StakingAmountViewModel>]

    func createViewModel(
        for selectedAccountId: AccountId,
        collatorInfo: CollatorStakingSelectionInfoProtocol,
        delegator: CollatorStakingDelegator?,
        priceData: PriceData?,
        locale: Locale
    ) throws -> ValidatorInfoViewModel
}

final class CollatorStakingInfoViewModelFactory: BaseValidatorInfoViewModelFactory {
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
        from collatorInfo: CollatorStakingSelectionInfoProtocol,
        price: PriceData?,
        locale: Locale
    ) -> BalanceViewModelProtocol {
        let amount = Decimal.fromSubstrateAmount(collatorInfo.minRewardableStake, precision: precision) ?? 0

        return balanceViewModelFactory.balanceFromPrice(amount, priceData: price).value(for: locale)
    }

    private func fetchStatus(
        for selectedAccountId: AccountId,
        collatorInfo: CollatorStakingSelectionInfoProtocol,
        delegator: CollatorStakingDelegator?
    ) -> CollatorStakingDelegationStatus {
        guard
            let delegator = delegator,
            let delegation = delegator.delegations.first(where: { $0.candidate == collatorInfo.accountId }) else {
            return .notRewarded
        }

        return collatorInfo.status(
            for: selectedAccountId,
            delegatorModel: delegator,
            stake: delegation.amount
        )
    }

    private func createExposure(
        for selectedAccountId: AccountId,
        collatorInfo: CollatorStakingSelectionInfoProtocol,
        delegator: CollatorStakingDelegator?,
        priceData: PriceData?,
        locale: Locale
    ) -> ValidatorInfoViewModel.Exposure {
        let formatter = NumberFormatter.quantity.localizableResource().value(for: locale)

        let delegatorsCount = collatorInfo.delegationCount

        let nominators = formatter.string(from: NSNumber(value: delegatorsCount)) ?? ""

        let maxNominatorsRewardedString = R.string(
            preferredLanguages: locale.rLanguages
        ).localizable.stakingMaxNominatorRewardedFormat(
            formatter.string(from: NSNumber(value: collatorInfo.maxRewardedDelegations)) ?? ""
        )

        let myNomination: ValidatorInfoViewModel.MyNomination?

        let status = fetchStatus(
            for: selectedAccountId,
            collatorInfo: collatorInfo,
            delegator: delegator
        )

        if status != .notElected {
            myNomination = ValidatorInfoViewModel.MyNomination(
                isRewarded: status != .notRewarded
            )
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

        let isDelegatedCollator = delegator?.hasDelegation(to: collatorInfo.accountId) ?? false

        let oversubscribed = isDelegatedCollator && status == .notRewarded

        return ValidatorInfoViewModel.Exposure(
            nominators: nominators,
            maxNominators: maxNominatorsRewardedString,
            myNomination: myNomination,
            totalStake: totalStake,
            minRewardableStake: minStake,
            estimatedReward: estimatedReward,
            oversubscribed: oversubscribed
        )
    }

    private func createOwnStakeTitle() -> LocalizableResource<String> {
        LocalizableResource { locale in
            R.string(preferredLanguages: locale.rLanguages).localizable.stakingValidatorOwnStake()
        }
    }

    private func createDelegatorsStakeTitle() -> LocalizableResource<String> {
        LocalizableResource { locale in
            R.string(preferredLanguages: locale.rLanguages).localizable.commonParastkDelegators()
        }
    }

    private func createTotalTitle() -> LocalizableResource<String> {
        LocalizableResource { locale in
            R.string(preferredLanguages: locale.rLanguages).localizable.walletTransferTotalTitle()
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

extension CollatorStakingInfoViewModelFactory: CollatorStakingInfoViewModelFactoryProtocol {
    func createViewModel(
        for selectedAccountId: AccountId,
        collatorInfo: CollatorStakingSelectionInfoProtocol,
        delegator: CollatorStakingDelegator?,
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

        if collatorInfo.isElected {
            let exposure = createExposure(
                for: selectedAccountId,
                collatorInfo: collatorInfo,
                delegator: delegator,
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
        from collatorInfo: CollatorStakingSelectionInfoProtocol,
        priceData: PriceData?
    ) -> [LocalizableResource<StakingAmountViewModel>] {
        var list: [LocalizableResource<StakingAmountViewModel>] = []

        if let ownStakeInPlank = collatorInfo.ownStake {
            let ownStake = Decimal.fromSubstrateAmount(ownStakeInPlank, precision: precision) ?? 0

            let ownStakeRow = createStakingAmountRow(
                title: createOwnStakeTitle(),
                amount: ownStake,
                priceData: priceData
            )

            list.append(ownStakeRow)
        }

        let delegatorsStake = Decimal.fromSubstrateAmount(collatorInfo.delegatorsStake, precision: precision) ?? 0

        let totalStake = Decimal.fromSubstrateAmount(collatorInfo.totalStake, precision: precision) ?? 0

        let delegatorsStakeRow = createStakingAmountRow(
            title: createDelegatorsStakeTitle(),
            amount: delegatorsStake,
            priceData: priceData
        )

        let totalStakeRow = createStakingAmountRow(
            title: createTotalTitle(),
            amount: totalStake,
            priceData: priceData
        )

        list.append(delegatorsStakeRow)
        list.append(totalStakeRow)

        return list
    }
}
