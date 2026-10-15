import Foundation
import Foundation_iOS

protocol SubnetPositionViewModelFactoryProtocol {
    func createViewModel(for state: SubtensorPositionState, locale: Locale) -> SubtensorPositionViewModel
}

final class SubtensorPositionViewModelFactory {
    let chainAsset: ChainAsset
    let iconFactory: SubtensorSubnetIconFactoryProtocol
    let assetIconFactory: AssetIconViewModelFactoryProtocol
    let displayAddressFactory: DisplayAddressViewModelFactoryProtocol
    let formatterFactory: AssetBalanceFormatterFactoryProtocol
    let balanceViewModelFactory: PrimitiveBalanceViewModelFactoryProtocol
    let priceWidgetFactory: SubtensorPriceWidgetFactoryProtocol

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

        priceWidgetFactory = SubtensorPriceWidgetViewModelFactory(
            chainAsset: chainAsset,
            priceAssetInfoFactory: priceAssetInfoFactory,
            formatterFactory: formatterFactory
        )
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
        let alphaInfo = chainAsset.assetDisplayInfo.subtensorAlpha(
            symbol: SubtensorSubnetNaming.symbol(for: state.netuid, in: state.catalogue)
        )

        let text = formatterFactory.createTokenFormatter(for: alphaInfo)
            .value(for: locale)
            .stringFromDecimal(decimal(amount)) ?? .subtensorUnknown(for: locale)

        return SubtensorSubnetNaming.isolatedLeftToRight(text)
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

    func createFiat(for state: SubtensorPositionState, locale: Locale) -> SubtensorRowState<String> {
        guard state.isRoot, let group = state.group else {
            return .hidden
        }

        switch state.price {
        case .loading:
            return .loading
        case let .loaded(price):
            return formatFiat(group.totalAlpha, price: price, locale: locale).map { .value($0) } ?? .hidden
        }
    }

    func createRewardsRow(for state: SubtensorPositionState, locale: Locale) -> SubtensorPositionRowViewModel {
        let value: SubtensorPositionValueViewModel

        if state.isClaimableFailed {
            value = .loaded(value: .subtensorUnknown(for: locale), detail: nil, isPositive: false)
        } else if let redeemable = state.claimable?.reduce(Balance.zero, { $0 + $1.redeemable }) {
            value = .loaded(
                value: formatTao(redeemable, locale: locale),
                detail: formatFiat(redeemable, price: state.price.value, locale: locale),
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

        let worthValue: SubtensorPositionValueViewModel

        if state.price == .loading || !state.isCatalogueResolved {
            worthValue = .loading
        } else if let taoValue = state.taoValue {
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

        return [worthRow]
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
                isActive: state.primaryPosition.map(\.isRegistered),
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

    func createClaimDetails(for state: SubtensorPositionState, locale: Locale) -> String? {
        guard !state.isClaimableFailed, let target = state.claimTarget else {
            return nil
        }

        return formatTao(target.redeemable, locale: locale)
    }

    func createActions(for state: SubtensorPositionState, locale: Locale) -> [SubtensorPositionActionViewModel] {
        let strings = R.string(preferredLanguages: locale.rLanguages).localizable

        let actions: [(SubtensorPositionAction, String)] = state.isRoot
            ? [
                (.claim, strings.stakingClaimRewards()),
                (.addStake, strings.stakingSubtensorUiPositionAddStake()),
                (.unstake, strings.stakingUnbond_v190())
            ]
            : [(.sell, strings.walletAssetSell()), (.buy, strings.walletAssetBuy())]

        return actions.map { action, title in
            SubtensorPositionActionViewModel(
                action: action,
                title: title,
                isEnabled: state.isEnabled(action),
                details: action == .claim ? createClaimDetails(for: state, locale: locale) : nil
            )
        }
    }

    func createValidator(for state: SubtensorPositionState, locale: Locale) -> SubtensorValidatorCardViewModel {
        let strings = R.string(preferredLanguages: locale.rLanguages).localizable
        let address = state.group.flatMap { try? $0.primaryHotkey.toAddress(using: chainAsset.chain.chainFormat) }

        let icon = address.flatMap { address in
            displayAddressFactory.createViewModel(
                from: DisplayAddress(address: address, username: state.validator?.name ?? "")
            ).imageViewModel
        }

        let name = state.isValidatorResolved
            ? state.validator?.name ?? address?.mediumTruncated ?? .subtensorUnknown(for: locale)
            : nil

        let rate: SubtensorRowState<String>

        if !state.isRateResolved {
            rate = .loading
        } else if state.isRoot || state.annualRate != nil {
            rate = .value(SubtensorApyFormatter.text(for: state.annualRate, style: .bare, locale: locale))
        } else {
            rate = .hidden
        }

        return SubtensorValidatorCardViewModel(
            icon: icon,
            name: name,
            subtitle: strings.stakingCommonValidator(),
            rate: rate,
            rateCaption: strings.stakingSubtensorV22EstApy()
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
            priceWidget: createPriceWidget(for: state, locale: locale),
            actions: createActions(for: state, locale: locale),
            validator: createValidator(for: state, locale: locale),
            notice: createNotice(for: state, locale: locale),
            isSyncFailed: state.isSyncFailed
        )
    }
}
