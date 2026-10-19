import Foundation
import BigInt
import Foundation_iOS
import SubstrateSdk

struct SubtensorValidatorInfoInput {
    let target: SubtensorStakeTarget
    let hotkey: AccountId
    let detail: SubtensorValidatorDirectoryItem?
    let needsChainDetail: Bool
    let annualRate: LoadableViewModelState<Decimal?>
    let alphaPrice: LoadableViewModelState<Balance?>
    let price: PriceData?
    var coverage: LoadableViewModelState<SubtensorValidatorCoverage?> = .loading
}

final class SubtensorValidatorInfoViewModelFactory {
    let chainAsset: ChainAsset
    let balanceViewModelFactory: BalanceViewModelFactoryProtocol

    private let displayAddressFactory = DisplayAddressViewModelFactory()
    private let stakeFormatter: LocalizableResource<TokenFormatter>
    private let takeFormatter: LocalizableResource<NumberFormatter>

    init(
        chainAsset: ChainAsset,
        balanceViewModelFactory: BalanceViewModelFactoryProtocol
    ) {
        self.chainAsset = chainAsset
        self.balanceViewModelFactory = balanceViewModelFactory
        stakeFormatter = AssetBalanceFormatterFactory().createCompactTokenFormatter(for: chainAsset.assetDisplayInfo)
        takeFormatter = NumberFormatter.subtensorPercentSingleHalfEven
    }

    func createViewModel(for input: SubtensorValidatorInfoInput, locale: Locale) -> SubtensorValidatorInfoViewModel {
        SubtensorValidatorInfoViewModel(
            coverage: createCoverage(for: input, locale: locale),
            account: createAccountViewModel(for: input),
            staking: input.detail.map { createStakingViewModel(for: $0, input: input, locale: locale) }
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
            denominator: stake.denominator * SubtensorPallet.alphaPriceScale
        ).decimalValue
    }
}

private extension SubtensorValidatorInfoViewModelFactory {
    func createCoverage(for input: SubtensorValidatorInfoInput, locale: Locale) -> LoadableViewModelState<String> {
        let strings = R.string(preferredLanguages: locale.rLanguages).localizable
        switch input.coverage {
        case .loading: return .loading
        case let .loaded(value), let .cached(value):
            return .loaded(
                value: value.map { strings.stakingSubtensorV22CoverageFormat($0.permitted, $0.total) }
                    ?? strings.stakingSubtensorUiValueUnknown()
            )
        }
    }

    func createAccountViewModel(for input: SubtensorValidatorInfoInput) -> DisplayAddressViewModel {
        let chainFormat = chainAsset.chain.chainFormat
        let address = (try? input.hotkey.toAddress(using: chainFormat)) ?? input.hotkey.toHex(includePrefix: true)

        let viewModel = displayAddressFactory.createViewModel(
            from: DisplayAddress(address: address, username: input.detail?.name ?? ""),
            using: chainFormat
        )

        return DisplayAddressViewModel(
            address: address.truncated(prefix: Constants.addressPrefix, suffix: Constants.addressSuffix),
            name: viewModel.name,
            imageViewModel: viewModel.imageViewModel
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
        let activeStatus = isActive ? strings.stakingNominatorStatusActive() : strings.stakingNominatorStatusInactive()

        let reward: LoadableViewModelState<String>
        let hasReward: Bool

        switch input.annualRate {
        case .loading:
            reward = .loading
            hasReward = false
        case let .cached(rate), let .loaded(rate):
            reward = .loaded(
                value: rate.map { SubtensorApyFormatter.text(for: $0, style: .trailing, locale: locale) }
                    ?? unknown
            )
            hasReward = rate != nil
        }

        return SubtensorValidatorInfoViewModel.Staking(
            status: input.needsChainDetail ? unknown : activeStatus,
            isActive: isActive,
            stake: createStakeViewModel(for: item, input: input, locale: locale),
            take: item.take.flatMap { takeFormatter.value(for: locale).stringFromDecimal($0) } ?? unknown,
            reward: reward,
            rewardDetail: hasReward ? strings.stakingSubtensorUiValidatorInfoRewardAverage() : nil,
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

private extension SubtensorValidatorInfoViewModelFactory {
    enum Constants {
        static let addressPrefix = 7
        static let addressSuffix = 5
    }
}
