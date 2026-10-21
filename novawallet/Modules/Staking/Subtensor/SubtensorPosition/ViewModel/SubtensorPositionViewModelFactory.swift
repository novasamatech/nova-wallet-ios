import Foundation
import Foundation_iOS

protocol SubtensorPositionViewModelFactoryProtocol {
    func createViewModel(for state: SubtensorPositionState, locale: Locale) -> SubtensorPositionViewModel
    func createPriceHeader(for state: SubtensorPositionState, locale: Locale) -> SubtensorSubnetPriceHeaderViewModel?
}

final class SubtensorPositionViewModelFactory {
    let chainAsset: ChainAsset
    let iconFactory: SubtensorSubnetIconFactoryProtocol = SubtensorSubnetIconViewModelFactory()
    let assetIconFactory: AssetIconViewModelFactoryProtocol = AssetIconViewModelFactory()
    let displayAddressFactory: DisplayAddressViewModelFactoryProtocol = DisplayAddressViewModelFactory()
    let balanceViewModelFactory: BalanceViewModelFactoryProtocol
    let costBasisViewModelFactory: SubtensorCostBasisViewModelFactory
    let priceWidgetFactory: SubtensorPriceWidgetFactoryProtocol

    init(
        chainAsset: ChainAsset,
        priceAssetInfoFactory: PriceAssetInfoFactoryProtocol
    ) {
        self.chainAsset = chainAsset

        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: chainAsset.assetDisplayInfo,
            priceAssetInfoFactory: priceAssetInfoFactory
        )

        self.balanceViewModelFactory = balanceViewModelFactory

        costBasisViewModelFactory = SubtensorCostBasisViewModelFactory(
            taoInfo: chainAsset.assetDisplayInfo,
            balanceViewModelFactory: balanceViewModelFactory
        )

        priceWidgetFactory = SubtensorPriceWidgetViewModelFactory(
            chainAsset: chainAsset,
            priceAssetInfoFactory: priceAssetInfoFactory
        )
    }
}

private extension SubtensorPositionViewModelFactory {
    func decimal(_ amount: Balance) -> Decimal {
        amount.decimal(assetInfo: chainAsset.assetDisplayInfo)
    }

    func formatTao(
        _ amount: Balance,
        roundingMode: NumberFormatter.RoundingMode = .down,
        locale: Locale
    ) -> String {
        balanceViewModelFactory.amountFromValue(decimal(amount), roundingMode: roundingMode).value(for: locale)
    }

    func formatFiat(_ amount: Balance, price: PriceData?, locale: Locale) -> String? {
        price.map { balanceViewModelFactory.priceFromAmount(decimal(amount), priceData: $0).value(for: locale) }
    }

    func formatAlpha(_ amount: Balance, state: SubtensorPositionState, locale: Locale) -> String {
        chainAsset.assetDisplayInfo.subtensorAlphaAmount(
            amount,
            netuid: state.netuid,
            catalogue: state.catalogue,
            locale: locale
        )
    }

    func formatDuration(blocks: UInt64, blockTime: BlockTime, locale: Locale) -> String {
        (TimeInterval(blocks) * blockTime.timeInterval).localizedDaysHoursOrFallbackMinutes(for: locale)
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
            value = .loaded(value: .subtensorUnknown(for: locale), detail: nil)
        } else if let redeemable = state.claimable?.reduce(Balance.zero, { $0 + $1.redeemable }) {
            value = .loaded(
                value: formatTao(redeemable, locale: locale),
                detail: formatFiat(redeemable, price: state.price.value, locale: locale)
            )
        } else {
            value = .loading
        }

        return SubtensorPositionRowViewModel(
            title: R.string(preferredLanguages: locale.rLanguages).localizable.commonRewards(),
            value: value,
            caption: createClaimMinimumCaption(for: state, locale: locale)
        )
    }

    func createClaimMinimumCaption(for state: SubtensorPositionState, locale: Locale) -> String? {
        guard
            !state.isClaimableFailed,
            let claimable = state.claimable,
            !claimable.contains(where: SubtensorRootClaimRule.isClaimable),
            let accrued = claimable.first(where: { $0.redeemable > 0 }) else {
            return nil
        }

        let minimum = formatTao(accrued.minimumClaim, roundingMode: .up, locale: locale)

        return R.string(preferredLanguages: locale.rLanguages).localizable
            .stakingSubtensorUiPositionClaimMinimumFormat(minimum)
    }

    func createWorthRow(for state: SubtensorPositionState, locale: Locale) -> SubtensorPositionRowViewModel {
        let strings = R.string(preferredLanguages: locale.rLanguages).localizable

        let worthValue: SubtensorPositionValueViewModel

        if state.price == .loading || !state.isCatalogueResolved {
            worthValue = .loading
        } else if let taoValue = state.taoValue {
            worthValue = .loaded(
                value: formatTao(taoValue, locale: locale).approximatelyEqual(),
                detail: formatFiat(taoValue, price: state.price.value, locale: locale)
            )
        } else {
            worthValue = .loaded(value: strings.stakingSubtensorUiPriceUnavailable(), detail: nil)
        }

        return SubtensorPositionRowViewModel(
            title: strings.stakingSubtensorUiPositionWorth(),
            value: worthValue,
            caption: nil
        )
    }

    func createAvgBuyPriceRow(for state: SubtensorPositionState, locale: Locale) -> SubtensorPositionRowViewModel? {
        let value = state.isCatalogueResolved
            ? costBasisViewModelFactory.createAvgBuyPrice(
                for: state.costBasis,
                alphaSymbol: SubtensorSubnetNaming.symbol(for: state.netuid, in: state.catalogue),
                locale: locale
            )
            : .loading

        return createCostBasisRow(
            title: R.string(preferredLanguages: locale.rLanguages).localizable.stakingSubtensorUiAvgBuyPrice(),
            value: value
        )
    }

    func createEarnedRow(for state: SubtensorPositionState, locale: Locale) -> SubtensorPositionRowViewModel? {
        guard state.costBasis != .resolved(.noPurchases), !state.isOwnTradeSettling else {
            return nil
        }

        let isLoading = state.costBasis == .loading || state.price == .loading || !state.isCatalogueResolved

        return createCostBasisRow(
            title: R.string(preferredLanguages: locale.rLanguages).localizable.stakingSubtensorUiEarned(),
            value: isLoading
                ? .loading
                : costBasisViewModelFactory.createEarned(
                    for: state.costBasis,
                    proceeds: state.worthNow,
                    taoPrice: state.price.value,
                    locale: locale
                )
        )
    }

    func createCostBasisRow(
        title: String,
        value: SubtensorRowState<SubtensorCostBasisValueViewModel>
    ) -> SubtensorPositionRowViewModel? {
        switch value {
        case .hidden:
            return nil
        case .loading:
            return SubtensorPositionRowViewModel(title: title, value: .loading, caption: nil)
        case let .value(viewModel):
            return SubtensorPositionRowViewModel(
                title: title,
                value: .loaded(value: viewModel.amount, detail: viewModel.detail),
                caption: nil,
                tone: viewModel.tone
            )
        }
    }

    func createSummary(for state: SubtensorPositionState, locale: Locale) -> SubtensorPositionSummaryViewModel {
        let isActive = state.hasValidatorList ? nil : state.primaryPosition?.isRegistered ?? true

        guard !state.isRoot else {
            return SubtensorPositionSummaryViewModel(
                icon: assetIconFactory.createAssetIconViewModel(from: chainAsset.assetDisplayInfo),
                caption: R.string(preferredLanguages: locale.rLanguages).localizable
                    .stakingSubtensorUiPositionStakedRoot(),
                amount: state.group.map { formatTao($0.totalAlpha, locale: locale) },
                fiat: createFiat(for: state, locale: locale),
                isActive: state.hasValidatorList ? nil : state.primaryPosition.map(\.isRegistered),
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
            rows: [
                createAvgBuyPriceRow(for: state, locale: locale),
                createWorthRow(for: state, locale: locale),
                createEarnedRow(for: state, locale: locale)
            ].compactMap { $0 }
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
        createValidatorCard(
            for: state.group?.primaryHotkey,
            subtitle: R.string(preferredLanguages: locale.rLanguages).localizable.stakingCommonValidator(),
            state: state,
            locale: locale
        )
    }

    func createValidators(for state: SubtensorPositionState, locale: Locale) -> [SubtensorValidatorCardViewModel] {
        guard state.hasValidatorList, let group = state.group else {
            return []
        }

        return group.positions.map { position in
            var card = createValidatorCard(
                for: position.hotkey,
                subtitle: state.isRoot
                    ? formatTao(position.stakeAlpha, locale: locale)
                    : formatAlpha(position.stakeAlpha, state: state, locale: locale),
                state: state,
                locale: locale
            )

            card.isActive = position.isRegistered

            return card
        }
    }

    func createValidatorCard(
        for hotkey: AccountId?,
        subtitle: String,
        state: SubtensorPositionState,
        locale: Locale
    ) -> SubtensorValidatorCardViewModel {
        let address = hotkey.flatMap { try? $0.toAddress(using: chainAsset.chain.chainFormat) }
        let validator = hotkey.flatMap { state.validators[$0] }

        let icon = address.flatMap { address in
            displayAddressFactory.createViewModel(
                from: DisplayAddress(address: address, username: validator?.name ?? "")
            ).imageViewModel
        }

        let isResolved = hotkey.map { state.isValidatorResolved($0) } ?? false
        let name = isResolved ? validator?.name ?? address?.mediumTruncated ?? .subtensorUnknown(for: locale) : nil
        let annualRate = hotkey.flatMap { state.annualRate(for: $0) }

        let rate: SubtensorRowState<String>

        if !state.isRateResolved {
            rate = .loading
        } else if annualRate != nil || (state.isRoot && state.yields != nil) {
            rate = .value(SubtensorApyFormatter.text(for: annualRate, style: .bare, locale: locale))
        } else {
            rate = .hidden
        }

        return SubtensorValidatorCardViewModel(
            icon: icon,
            name: name,
            subtitle: subtitle,
            rate: rate,
            rateCaption: R.string(preferredLanguages: locale.rLanguages).localizable.stakingSubtensorV22EstApy()
        )
    }

    func createNotice(for state: SubtensorPositionState, locale: Locale) -> SubtensorPositionNoticeViewModel? {
        let strings = R.string(preferredLanguages: locale.rLanguages).localizable

        if state.isRoot {
            guard
                let remaining = state.holdRemainingBlocks,
                let hold = state.primaryHold,
                let blockTime = state.blockTime else {
                return nil
            }

            return SubtensorPositionNoticeViewModel(
                title: strings.stakingSubtensorUiPositionHoldTitle(),
                timeLeft: strings.commonTimeLeftFormat(
                    formatDuration(blocks: remaining, blockTime: blockTime, locale: locale)
                ),
                message: strings.stakingSubtensorUiPositionHoldMessageFormat(
                    formatDuration(blocks: hold.interval, blockTime: blockTime, locale: locale)
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

extension SubtensorPositionViewModelFactory: SubtensorPositionViewModelFactoryProtocol {
    func createViewModel(for state: SubtensorPositionState, locale: Locale) -> SubtensorPositionViewModel {
        SubtensorPositionViewModel(
            title: createTitle(for: state, locale: locale),
            summary: createSummary(for: state, locale: locale),
            priceWidget: createPriceWidget(for: state, locale: locale),
            actions: createActions(for: state, locale: locale),
            validator: createValidator(for: state, locale: locale),
            validators: createValidators(for: state, locale: locale),
            notice: createNotice(for: state, locale: locale),
            isSyncFailed: state.isSyncFailed
        )
    }
}
