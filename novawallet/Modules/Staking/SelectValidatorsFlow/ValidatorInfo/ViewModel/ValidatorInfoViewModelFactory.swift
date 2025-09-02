import Foundation
import SubstrateSdk
import Foundation_iOS

protocol ValidatorInfoViewModelFactoryProtocol {
    func createStakingAmountsViewModel(
        from validatorInfo: ValidatorInfoProtocol,
        priceData: PriceData?
    ) -> [LocalizableResource<StakingAmountViewModel>]

    func createViewModel(
        from validatorInfo: ValidatorInfoProtocol,
        priceData: PriceData?,
        locale: Locale
    ) -> ValidatorInfoViewModel
}

final class ValidatorInfoViewModelFactory: BaseValidatorInfoViewModelFactory {
    private let balanceViewModelFactory: BalanceViewModelFactoryProtocol

    private lazy var accountViewModelFactory = WalletAccountViewModelFactory()

    init(balanceViewModelFactory: BalanceViewModelFactoryProtocol) {
        self.balanceViewModelFactory = balanceViewModelFactory
    }

    private func createExposure(
        from validatorInfo: ValidatorInfoProtocol,
        priceData: PriceData?,
        locale: Locale
    ) -> ValidatorInfoViewModel.Exposure {
        let formatter = NumberFormatter.quantity.localizableResource().value(for: locale)

        let nominatorsCount = validatorInfo.stakeInfo?.nominators.count ?? 0
        let optMaxNominatorsRewarded = validatorInfo.stakeInfo?.maxNominatorsRewarded
        let maxNominatorsRewarded = optMaxNominatorsRewarded.map { Int($0) } ?? nominatorsCount

        let nominators = formatter.string(from: NSNumber(value: nominatorsCount)) ?? ""

        let maxNominatorsRewardedString = R.string.localizable.stakingMaxNominatorRewardedFormat(
            formatter.string(from: NSNumber(value: maxNominatorsRewarded)) ?? "",
            preferredLanguages: locale.rLanguages
        )

        let myNomination: ValidatorInfoViewModel.MyNomination?

        switch validatorInfo.myNomination {
        case let .active(allocation):
            myNomination = ValidatorInfoViewModel.MyNomination(isRewarded: allocation.isRewarded)
        case .elected, .unelected, .none:
            myNomination = nil
        }

        let totalStake = balanceViewModelFactory.balanceFromPrice(
            validatorInfo.totalStake,
            priceData: priceData
        ).value(for: locale)

        let estimatedRewardDecimal = validatorInfo.stakeInfo?.stakeReturn ?? 0.0
        let estimatedReward = NumberFormatter.percentAPY.localizableResource()
            .value(for: locale).stringFromDecimal(estimatedRewardDecimal) ?? ""

        return ValidatorInfoViewModel.Exposure(
            nominators: nominators,
            maxNominators: maxNominatorsRewardedString,
            myNomination: myNomination,
            totalStake: totalStake,
            minRewardableStake: nil,
            estimatedReward: estimatedReward,
            oversubscribed: validatorInfo.stakeInfo?.oversubscribed ?? false
        )
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

// MARK: - ValidatorInfoViewModelFactoryProtocol

extension ValidatorInfoViewModelFactory: ValidatorInfoViewModelFactoryProtocol {
    func createViewModel(
        from validatorInfo: ValidatorInfoProtocol,
        priceData: PriceData?,
        locale: Locale
    ) -> ValidatorInfoViewModel {
        let accountViewModel = accountViewModelFactory.createViewModel(from: validatorInfo)

        let status: ValidatorInfoViewModel.StakingStatus

        if validatorInfo.stakeInfo != nil {
            let exposure = createExposure(from: validatorInfo, priceData: priceData, locale: locale)
            status = .elected(exposure: exposure)
        } else {
            status = .unelected
        }

        let staking = ValidatorInfoViewModel.Staking(
            status: status,
            slashed: validatorInfo.hasSlashes
        )

        let identityItems = validatorInfo.identity.map { identity in
            createIdentityViewModel(from: identity, locale: locale)
        }

        return ValidatorInfoViewModel(
            account: accountViewModel,
            staking: staking,
            identity: identityItems
        )
    }

    func createStakingAmountsViewModel(
        from validatorInfo: ValidatorInfoProtocol,
        priceData: PriceData?
    ) -> [LocalizableResource<StakingAmountViewModel>] {
        let nominatorsStake = validatorInfo.stakeInfo?.nominators
            .map(\.stake)
            .reduce(0, +) ?? 0.0

        return [
            createStakingAmountRow(
                title: createOwnStakeTitle(),
                amount: (validatorInfo.stakeInfo?.totalStake ?? 0.0) - nominatorsStake,
                priceData: priceData
            ),
            createStakingAmountRow(
                title: createNominatorsStakeTitle(),
                amount: nominatorsStake,
                priceData: priceData
            ),
            createStakingAmountRow(
                title: createTotalTitle(),
                amount: validatorInfo.stakeInfo?.totalStake ?? 0.0,
                priceData: priceData
            )
        ]
    }
}
