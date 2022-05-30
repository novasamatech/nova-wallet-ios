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

final class ParaStkCollatorInfoViewModelFactory {
    private let balanceViewModelFactory: BalanceViewModelFactoryProtocol

    private lazy var accountViewModelFactory = WalletAccountViewModelFactory()

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

    // MARK: - Private functions

    // MARK: Identity Rows

    private func createLegalRow(with legal: String, locale: Locale) -> ValidatorInfoViewModel.IdentityItem {
        let title = R.string.localizable.identityLegalNameTitle(preferredLanguages: locale.rLanguages)
        return .init(title: title, value: .text(legal))
    }

    private func createEmailRow(with email: String, locale: Locale) -> ValidatorInfoViewModel.IdentityItem {
        let title = R.string.localizable.identityEmailTitle(preferredLanguages: locale.rLanguages)
        return .init(title: title, value: .link(email, tag: .email))
    }

    private func createWebRow(with web: String, locale: Locale) -> ValidatorInfoViewModel.IdentityItem {
        let title = R.string.localizable.identityWebTitle(preferredLanguages: locale.rLanguages)
        return .init(title: title, value: .link(web, tag: .web))
    }

    private func createTwitterRow(with twitter: String) -> ValidatorInfoViewModel.IdentityItem {
        .init(title: "Twitter", value: .link(twitter, tag: .twitter))
    }

    private func createRiotRow(with riot: String, locale: Locale) -> ValidatorInfoViewModel.IdentityItem {
        let title = R.string.localizable.identityRiotNameTitle(preferredLanguages: locale.rLanguages)
        return .init(title: title, value: .link(riot, tag: .riot))
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

        let estimatedReward = NumberFormatter.percentAPY.localizableResource()
            .value(for: locale).stringFromDecimal(collatorInfo.apr) ?? ""

        return ValidatorInfoViewModel.Exposure(
            nominators: nominators,
            maxNominators: maxNominatorsRewardedString,
            myNomination: myNomination,
            totalStake: totalStake,
            estimatedReward: estimatedReward,
            oversubscribed: false
        )
    }

    private func createIdentityViewModel(
        from identity: AccountIdentity,
        locale: Locale
    ) -> [ValidatorInfoViewModel.IdentityItem] {
        var identityItems: [ValidatorInfoViewModel.IdentityItem] = []

        if let legal = identity.legal {
            identityItems.append(createLegalRow(with: legal, locale: locale))
        }

        if let email = identity.email {
            identityItems.append(createEmailRow(with: email, locale: locale))
        }

        if let web = identity.web {
            identityItems.append(createWebRow(with: web, locale: locale))
        }

        if let twitter = identity.twitter {
            identityItems.append(createTwitterRow(with: twitter))
        }

        if let riot = identity.riot {
            identityItems.append(createRiotRow(with: riot, locale: locale))
        }

        return identityItems
    }

    private func createOwnStakeTitle() -> LocalizableResource<String> {
        LocalizableResource { locale in
            R.string.localizable.stakingValidatorOwnStake(preferredLanguages: locale.rLanguages)
        }
    }

    private func createNominatorsStakeTitle() -> LocalizableResource<String> {
        LocalizableResource { locale in
            R.string.localizable.stakingValidatorNominators(preferredLanguages: locale.rLanguages)
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
        let accountViewModel = accountViewModelFactory.createViewModel(
            from: address,
            identity: collatorInfo.identity
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
                title: createNominatorsStakeTitle(),
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
