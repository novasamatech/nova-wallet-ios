import Foundation
import Foundation_iOS

protocol SubnetPositionViewModelFactoryProtocol {
    func createViewModel(for state: SubtensorPositionState, locale: Locale) -> SubtensorPositionViewModel
}

final class SubtensorPositionViewModelFactory {
    static let periods: [SubtensorPricePeriod] = [.day, .week, .month, .quarter, .year]
    static let defaultPeriod = SubtensorPricePeriod.week

    let chainAsset: ChainAsset
    let iconFactory: SubtensorSubnetIconFactoryProtocol
    let assetIconFactory: AssetIconViewModelFactoryProtocol
    let displayAddressFactory: DisplayAddressViewModelFactoryProtocol
    let formatterFactory: AssetBalanceFormatterFactoryProtocol
    let balanceViewModelFactory: PrimitiveBalanceViewModelFactoryProtocol

    init(
        chainAsset: ChainAsset,
        priceAssetInfoFactory: PriceAssetInfoFactoryProtocol,
        iconFactory: SubtensorSubnetIconFactoryProtocol = SubtensorSubnetIconViewModelFactory(),
        assetIconFactory: AssetIconViewModelFactoryProtocol = AssetIconViewModelFactory(),
        displayAddressFactory: DisplayAddressViewModelFactoryProtocol = DisplayAddressViewModelFactory(),
        formatterFactory: AssetBalanceFormatterFactoryProtocol = AssetBalanceFormatterFactory()
    ) {
        self.chainAsset = chainAsset
        self.iconFactory = iconFactory
        self.assetIconFactory = assetIconFactory
        self.displayAddressFactory = displayAddressFactory
        self.formatterFactory = formatterFactory

        balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: chainAsset.assetDisplayInfo,
            priceAssetInfoFactory: priceAssetInfoFactory
        )
    }
}

extension SubtensorPositionViewModelFactory {
    func unknownValue(for locale: Locale) -> String {
        R.string(preferredLanguages: locale.rLanguages).localizable.stakingSubtensorUiValueUnknown()
    }
}

private extension SubtensorPositionViewModelFactory {
    func decimal(_ amount: Balance) -> Decimal {
        amount.decimal(assetInfo: chainAsset.assetDisplayInfo)
    }

    func formatTao(_ amount: Balance, locale: Locale) -> String {
        balanceViewModelFactory.amountFromValue(decimal(amount), roundingMode: .down).value(for: locale)
    }

    func formatFiat(_ amount: Balance, price: PriceData?, locale: Locale) -> String? {
        price.map { balanceViewModelFactory.priceFromAmount(decimal(amount), priceData: $0).value(for: locale) }
    }

    func formatAlpha(_ amount: Balance, state: SubtensorPositionState, locale: Locale) -> String {
        let taoInfo = chainAsset.assetDisplayInfo

        let alphaInfo = AssetBalanceDisplayInfo(
            displayPrecision: taoInfo.displayPrecision,
            assetPrecision: taoInfo.assetPrecision,
            symbol: SubtensorSubnetNaming.symbol(for: state.netuid, in: state.catalogue),
            symbolValueSeparator: taoInfo.symbolValueSeparator,
            symbolPosition: taoInfo.symbolPosition,
            icon: nil
        )

        let text = formatterFactory.createTokenFormatter(for: alphaInfo)
            .value(for: locale)
            .stringFromDecimal(decimal(amount)) ?? unknownValue(for: locale)

        return "\u{2066}\(text)\u{2069}"
    }

    func formatDuration(blocks: UInt64, locale: Locale) -> String {
        let time = (TimeInterval(blocks) * TimeInterval(SubtensorStakingFlowConstants.blockTimeMillis)).seconds

        return time.localizedDaysHoursOrFallbackMinutes(for: locale)
    }

    func createTitle(for state: SubtensorPositionState, locale: Locale) -> String? {
        guard !state.isRoot else {
            return R.string(preferredLanguages: locale.rLanguages).localizable.stakingSubtensorUiRootStaking()
        }

        guard state.isCatalogueResolved else {
            return nil
        }

        return SubtensorSubnetNaming.titleWithSymbol(for: state.netuid, in: state.catalogue, locale: locale)
    }

    func createFiat(for state: SubtensorPositionState, locale: Locale) -> SubtensorPortfolioLoadable<String> {
        guard state.isRoot, let group = state.group else {
            return .hidden
        }

        switch state.price {
        case .loading:
            return .loading
        case let .loaded(price):
            return formatFiat(group.totalAlpha, price: price, locale: locale).map { .loaded($0) } ?? .hidden
        }
    }

    func createRewardsRow(for state: SubtensorPositionState, locale: Locale) -> SubtensorPositionRowViewModel {
        let value: SubtensorPositionValueViewModel

        if state.isClaimableFailed {
            value = .loaded(value: unknownValue(for: locale), detail: nil, isPositive: false)
        } else if let claimable = state.claimable {
            value = .loaded(
                value: formatTao(claimable.totalRedeemable, locale: locale),
                detail: formatFiat(claimable.totalRedeemable, price: state.price.value, locale: locale),
                isPositive: false
            )
        } else {
            value = .loading
        }

        return SubtensorPositionRowViewModel(
            title: R.string(preferredLanguages: locale.rLanguages).localizable.commonRewards(),
            value: value
        )
    }

    func createSubnetRows(for state: SubtensorPositionState, locale: Locale) -> [SubtensorPositionRowViewModel] {
        let strings = R.string(preferredLanguages: locale.rLanguages).localizable

        let apyRow: SubtensorPositionRowViewModel?

        if !state.isRateResolved {
            apyRow = SubtensorPositionRowViewModel(title: strings.stakingEstimatedEarnings(), value: .loading)
        } else {
            apyRow = state.annualRate.map { rate in
                SubtensorPositionRowViewModel(
                    title: strings.stakingEstimatedEarnings(),
                    value: .loaded(
                        value: SubtensorApyFormatter.text(for: rate, style: .trailing, locale: locale),
                        detail: nil,
                        isPositive: true
                    )
                )
            }
        }

        let worthValue: SubtensorPositionValueViewModel

        if state.price == .loading {
            worthValue = .loading
        } else if let taoValue = state.group?.taoValue {
            worthValue = .loaded(
                value: formatTao(taoValue, locale: locale).approximatelyEqual(),
                detail: formatFiat(taoValue, price: state.price.value, locale: locale),
                isPositive: false
            )
        } else {
            worthValue = .loaded(value: strings.stakingSubtensorUiPriceUnavailable(), detail: nil, isPositive: false)
        }

        let worthRow = SubtensorPositionRowViewModel(
            title: strings.stakingSubtensorUiPositionWorth(),
            value: worthValue
        )

        return [apyRow, worthRow].compactMap { $0 }
    }

    func createSummary(for state: SubtensorPositionState, locale: Locale) -> SubtensorPositionSummaryViewModel {
        let isActive = state.primaryPosition?.isRegistered ?? true

        guard !state.isRoot else {
            return SubtensorPositionSummaryViewModel(
                icon: assetIconFactory.createAssetIconViewModel(from: chainAsset.assetDisplayInfo),
                caption: R.string(preferredLanguages: locale.rLanguages).localizable
                    .stakingSubtensorUiPositionStakedRoot(),
                amount: state.group.map { formatTao($0.totalAlpha, locale: locale) },
                fiat: createFiat(for: state, locale: locale),
                isActive: isActive,
                rows: [createRewardsRow(for: state, locale: locale)]
            )
        }

        let isResolved = state.isCatalogueResolved

        return SubtensorPositionSummaryViewModel(
            icon: isResolved
                ? iconFactory.icon(for: state.catalogue?.subnet(for: state.netuid), logos: state.subnetLogos)
                : nil,
            caption: isResolved
                ? SubtensorSubnetNaming.titleWithSymbol(for: state.netuid, in: state.catalogue, locale: locale)
                : nil,
            amount: isResolved ? state.group.map { formatAlpha($0.totalAlpha, state: state, locale: locale) } : nil,
            fiat: .hidden,
            isActive: isResolved ? isActive : nil,
            rows: createSubnetRows(for: state, locale: locale)
        )
    }

    func createActions(for state: SubtensorPositionState, locale: Locale) -> [SubtensorPositionActionViewModel] {
        let strings = R.string(preferredLanguages: locale.rLanguages).localizable

        let actions: [(SubtensorPositionAction, String)] = state.isRoot
            ? [(.addStake, strings.stakingSubtensorUiPositionAddStake()), (.unstake, strings.stakingUnbond_v190())]
            : [(.sell, strings.walletAssetSell()), (.buy, strings.walletAssetBuy())]

        return actions.map { action, title in
            SubtensorPositionActionViewModel(action: action, title: title, isEnabled: state.isEnabled(action))
        }
    }

    func createValidator(for state: SubtensorPositionState, locale: Locale) -> SubtensorPositionValidatorViewModel {
        let strings = R.string(preferredLanguages: locale.rLanguages).localizable
        let address = state.group.flatMap { try? $0.primaryHotkey.toAddress(using: chainAsset.chain.chainFormat) }

        let icon = address.flatMap { address in
            displayAddressFactory.createViewModel(
                from: DisplayAddress(address: address, username: state.validator?.name ?? "")
            ).imageViewModel
        }

        let name = state.isValidatorResolved
            ? state.validator?.name ?? address?.mediumTruncated ?? unknownValue(for: locale)
            : nil

        let rate: SubtensorPortfolioLoadable<String>

        if !state.isRateResolved {
            rate = .loading
        } else if let annualRate = state.annualRate {
            rate = .loaded(SubtensorApyFormatter.text(for: annualRate, style: .bare, locale: locale))
        } else {
            rate = .hidden
        }

        return SubtensorPositionValidatorViewModel(
            icon: icon,
            name: name,
            subtitle: strings.stakingCommonValidator(),
            rate: rate,
            rateCaption: strings.stakingSubtensorUiValidatorSortApy()
        )
    }

    func createNotice(for state: SubtensorPositionState, locale: Locale) -> SubtensorPositionNoticeViewModel? {
        let strings = R.string(preferredLanguages: locale.rLanguages).localizable

        if state.isRoot {
            guard let remaining = state.holdRemainingBlocks, let hold = state.primaryHold else {
                return nil
            }

            return SubtensorPositionNoticeViewModel(
                title: strings.stakingSubtensorUiPositionHoldTitle(),
                timeLeft: strings.commonTimeLeftFormat(formatDuration(blocks: remaining, locale: locale)),
                message: strings.stakingSubtensorUiPositionHoldMessageFormat(
                    formatDuration(blocks: hold.interval, locale: locale)
                )
            )
        }

        guard state.isCatalogueResolved, let basis = state.unstakeBasis, basis.locked > 0 else {
            return nil
        }

        let locked = formatAlpha(basis.locked, state: state, locale: locale)

        return SubtensorPositionNoticeViewModel(
            title: strings.stakingSubtensorUiPositionLockedFormat(locked),
            timeLeft: nil,
            message: basis.available == 0
                ? strings.stakingSubtensorUnstakeNothingAvailableHint()
                : strings.stakingSubtensorUnstakeLockedPortionHint(locked)
        )
    }
}

extension SubtensorPositionViewModelFactory: SubnetPositionViewModelFactoryProtocol {
    func createViewModel(for state: SubtensorPositionState, locale: Locale) -> SubtensorPositionViewModel {
        SubtensorPositionViewModel(
            title: createTitle(for: state, locale: locale),
            summary: createSummary(for: state, locale: locale),
            chart: createChart(for: state, locale: locale),
            actions: createActions(for: state, locale: locale),
            validator: createValidator(for: state, locale: locale),
            notice: createNotice(for: state, locale: locale),
            isSyncFailed: state.isSyncFailed
        )
    }
}
