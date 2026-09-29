import Foundation
import BigInt
import Foundation_iOS
import SubstrateSdk

struct SubtensorValidatorInfoInput {
    let target: SubtensorStakeTarget
    let hotkey: AccountId
    let detail: SubtensorValidatorDetail?
    let annualRate: LoadableViewModelState<Decimal?>
    let alphaPrice: LoadableViewModelState<Balance?>
    let price: PriceData?
}

final class SubtensorValidatorInfoViewModelFactory {
    let chainAsset: ChainAsset
    let balanceViewModelFactory: BalanceViewModelFactoryProtocol

    private let displayAddressFactory = DisplayAddressViewModelFactory()
    private let stakeFormatter: LocalizableResource<TokenFormatter>
    private let takeFormatter: LocalizableResource<NumberFormatter>

    init(
        chainAsset: ChainAsset,
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        formatterFactory: AssetBalanceFormatterFactoryProtocol = AssetBalanceFormatterFactory()
    ) {
        self.chainAsset = chainAsset
        self.balanceViewModelFactory = balanceViewModelFactory
        stakeFormatter = formatterFactory.createCompactTokenFormatter(for: chainAsset.assetDisplayInfo)
        takeFormatter = NumberFormatter.percentSingleHalfEven.localizableResource()
    }

    func createViewModel(for input: SubtensorValidatorInfoInput, locale: Locale) -> SubtensorValidatorInfoViewModel {
        SubtensorValidatorInfoViewModel(
            account: createAccountViewModel(for: input),
            staking: input.detail.map { createStakingViewModel(for: $0.item, input: input, locale: locale) }
        )
    }

    static func isActive(_ item: SubtensorValidatorDirectoryItem, isRoot: Bool) -> Bool {
        guard let status = item.status else {
            return false
        }

        return isRoot || (status.hasPermit == true && status.isActive == true)
    }

    static func taoStake(
        for item: SubtensorValidatorDirectoryItem,
        isRoot: Bool,
        alphaPrice: Balance?
    ) -> Decimal? {
        guard let stake = item.reportedStake else {
            return nil
        }

        guard !isRoot else {
            return stake.decimalValue
        }

        guard let alphaPrice else {
            return nil
        }

        return BigRational(
            numerator: stake.numerator * alphaPrice,
            denominator: stake.denominator * SubtensorStakingPallet.alphaPriceScale
        ).decimalValue
    }
}

private extension SubtensorValidatorInfoViewModelFactory {
    func createAccountViewModel(for input: SubtensorValidatorInfoInput) -> DisplayAddressViewModel {
        let chainFormat = chainAsset.chain.chainFormat
        let address = (try? input.hotkey.toAddress(using: chainFormat)) ?? input.hotkey.toHex(includePrefix: true)

        return displayAddressFactory.createViewModel(
            from: DisplayAddress(address: address, username: input.detail?.item.name ?? ""),
            using: chainFormat
        )
    }

    func createStakingViewModel(
        for item: SubtensorValidatorDirectoryItem,
        input: SubtensorValidatorInfoInput,
        locale: Locale
    ) -> SubtensorValidatorInfoViewModel.Staking {
        let strings = R.string(preferredLanguages: locale.rLanguages).localizable
        let isRoot = input.target.isRoot
        let isActive = Self.isActive(item, isRoot: isRoot)
        let unknown = strings.stakingSubtensorUiValueUnknown()

        let reward: LoadableViewModelState<String>
        let hasReward: Bool

        switch input.annualRate {
        case .loading:
            reward = .loading
            hasReward = false
        case let .cached(rate), let .loaded(rate):
            reward = .loaded(value: rate.map { SubtensorApyFormatter.text(for: $0, style: .trailing, locale: locale) }
                ?? unknown)
            hasReward = rate != nil
        }

        return SubtensorValidatorInfoViewModel.Staking(
            status: isActive ? strings.stakingNominatorStatusActive() : strings.stakingNominatorStatusInactive(),
            isActive: isActive,
            stakeTitle: isRoot
                ? strings.stakingSubtensorUiValidatorInfoStakedRoot()
                : strings.stakingSubtensorUiValidatorInfoStakedSubnet(),
            stake: createStakeViewModel(for: item, input: input, locale: locale),
            take: item.take.flatMap { takeFormatter.value(for: locale).stringFromDecimal($0) } ?? unknown,
            reward: reward,
            hasReward: hasReward
        )
    }

    func createStakeViewModel(
        for item: SubtensorValidatorDirectoryItem,
        input: SubtensorValidatorInfoInput,
        locale: Locale
    ) -> LoadableViewModelState<SubtensorValidatorInfoViewModel.Stake> {
        let alphaPrice: Balance?

        switch input.alphaPrice {
        case .loading:
            return .loading
        case let .cached(value), let .loaded(value):
            alphaPrice = value
        }

        let unknown = R.string(preferredLanguages: locale.rLanguages).localizable.stakingSubtensorUiValueUnknown()

        guard let amount = Self.taoStake(for: item, isRoot: input.target.isRoot, alphaPrice: alphaPrice) else {
            return .loaded(value: SubtensorValidatorInfoViewModel.Stake(amount: unknown, price: nil))
        }

        let amountText = stakeFormatter.value(for: locale).stringFromDecimal(amount) ?? unknown
        let priceText = input.price.map { priceData in
            balanceViewModelFactory.priceFromAmount(amount, priceData: priceData).value(for: locale)
        }

        return .loaded(value: SubtensorValidatorInfoViewModel.Stake(amount: amountText, price: priceText))
    }
}
