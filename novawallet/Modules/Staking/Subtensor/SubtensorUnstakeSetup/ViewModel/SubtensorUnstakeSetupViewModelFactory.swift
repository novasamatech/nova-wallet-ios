import BigInt
import Foundation

final class SubtensorUnstakeSetupViewModelFactory {
    let chainAsset: ChainAsset
    let balanceViewModelFactory: BalanceViewModelFactoryProtocol
    let quoteViewModelFactory: SubtensorQuoteViewModelFactoryProtocol
    let displayAddressFactory: DisplayAddressViewModelFactoryProtocol
    let iconFactory: SubtensorSubnetIconFactoryProtocol
    let assetIconFactory: AssetIconViewModelFactoryProtocol

    private let formatterFactory = AssetBalanceFormatterFactory()

    init(
        chainAsset: ChainAsset,
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        quoteViewModelFactory: SubtensorQuoteViewModelFactoryProtocol,
        displayAddressFactory: DisplayAddressViewModelFactoryProtocol = DisplayAddressViewModelFactory(),
        iconFactory: SubtensorSubnetIconFactoryProtocol = SubtensorSubnetIconViewModelFactory(),
        assetIconFactory: AssetIconViewModelFactoryProtocol = AssetIconViewModelFactory()
    ) {
        self.chainAsset = chainAsset
        self.balanceViewModelFactory = balanceViewModelFactory
        self.quoteViewModelFactory = quoteViewModelFactory
        self.displayAddressFactory = displayAddressFactory
        self.iconFactory = iconFactory
        self.assetIconFactory = assetIconFactory
    }

    func createViewModel(
        for input: SubtensorUnstakeSetupViewModelInput,
        locale: Locale
    ) -> SubtensorUnstakeSetupViewModel {
        let strings = R.string(preferredLanguages: locale.rLanguages).localizable

        return SubtensorUnstakeSetupViewModel(
            title: createTitle(for: input, locale: locale),
            header: createHeader(for: input, locale: locale),
            inputPrice: createInputPrice(for: input, locale: locale),
            isInputEnabled: !input.isFullyLocked,
            details: createDetails(for: input, locale: locale),
            note: createRootNote(for: input, locale: locale),
            feeWarning: createFeeWarning(for: input, locale: locale),
            feeDisclosure: input.isRoot ? nil : quoteViewModelFactory.novaFeeDisclosure(locale: locale),
            holdWarning: createHoldWarning(for: input, locale: locale),
            caption: input.isRoot ? nil : strings.stakingSubtensorUiSafetyNote(),
            action: createAction(for: input, locale: locale)
        )
    }

    func createAssetViewModel(
        for netuid: UInt16,
        catalogue: SubtensorSubnetCatalogue?,
        subnetLogos: SubtensorSubnetLogos?,
        locale: Locale
    ) -> AssetViewModel {
        guard netuid != SubtensorStakingPallet.rootNetuid else {
            let info = chainAsset.assetDisplayInfo

            return AssetViewModel(
                symbol: info.symbol,
                imageViewModel: assetIconFactory.createAssetIconViewModel(
                    for: info.icon?.getPath(),
                    defaultURL: info.icon?.getURL()
                )
            )
        }

        return AssetViewModel(
            symbol: SubtensorSubnetNaming.title(for: netuid, in: catalogue, locale: locale),
            imageViewModel: iconFactory.icon(for: catalogue?.subnet(for: netuid), logos: subnetLogos)
        )
    }

    func inputDisplayInfo(for netuid: UInt16, catalogue: SubtensorSubnetCatalogue?) -> AssetBalanceDisplayInfo {
        let taoInfo = chainAsset.assetDisplayInfo

        guard netuid != SubtensorStakingPallet.rootNetuid else {
            return taoInfo
        }

        return AssetBalanceDisplayInfo(
            displayPrecision: taoInfo.displayPrecision,
            assetPrecision: taoInfo.assetPrecision,
            symbol: SubtensorSubnetNaming.symbol(for: netuid, in: catalogue),
            symbolValueSeparator: taoInfo.symbolValueSeparator,
            symbolPosition: taoInfo.symbolPosition,
            icon: nil
        )
    }
}

private extension SubtensorUnstakeSetupViewModelFactory {
    func formatAmount(_ amount: Balance, input: SubtensorUnstakeSetupViewModelInput, locale: Locale) -> String {
        let displayInfo = inputDisplayInfo(for: input.netuid, catalogue: input.catalogue)
        let decimal = amount.decimal(assetInfo: displayInfo)

        let formatter = formatterFactory.createTokenFormatter(for: displayInfo).value(for: locale)

        return formatter.stringFromDecimal(decimal) ?? ""
    }

    func formatFee(_ fee: ExtrinsicFeeProtocol, price: PriceData?, locale: Locale) -> BalanceViewModelProtocol {
        let feeDecimal = fee.amount.decimal(assetInfo: chainAsset.assetDisplayInfo)

        return balanceViewModelFactory.balanceFromPrice(
            feeDecimal,
            priceData: price,
            roundingMode: .up
        ).value(for: locale)
    }

    func createTitle(for input: SubtensorUnstakeSetupViewModelInput, locale: Locale) -> String {
        let strings = R.string(preferredLanguages: locale.rLanguages).localizable

        guard !input.isRoot else {
            return strings.stakingSubtensorUiUnstakeFromRoot()
        }

        let subnetTitle = SubtensorSubnetNaming.titleWithSymbol(for: input.netuid, in: input.catalogue, locale: locale)

        return strings.stakingSubtensorUiSellTitleFormat(subnetTitle)
    }

    func createHeader(
        for input: SubtensorUnstakeSetupViewModelInput,
        locale: Locale
    ) -> SubtensorUnstakeHeaderViewModel {
        let strings = R.string(preferredLanguages: locale.rLanguages).localizable

        guard input.isRoot else {
            return SubtensorUnstakeHeaderViewModel(
                title: strings.stakingSubtensorUiYouSell(),
                prefix: strings.swapsSetupAssetMax(),
                value: input.maxAmount.map { formatAmount($0, input: input, locale: locale).isolatedLeftToRight() },
                link: nil,
                isEnabled: (input.maxAmount ?? 0) > 0
            )
        }

        let link = strings.stakingUnstakeAll()

        return SubtensorUnstakeHeaderViewModel(
            title: strings.stakingSubtensorUiYouUnstake(),
            prefix: strings.commonStakedPrefix(),
            value: input.basis.map { basis in
                strings.stakingSubtensorUiJoinDotFormat(formatAmount(basis.total, input: input, locale: locale), link)
            },
            link: link,
            isEnabled: (input.maxAmount ?? 0) > 0
        )
    }

    func createInputPrice(for input: SubtensorUnstakeSetupViewModelInput, locale: Locale) -> String? {
        guard let price = input.price else {
            return nil
        }

        let amount = input.amount ?? 0
        let taoAmount: Balance

        if input.isRoot {
            taoAmount = amount
        } else {
            guard let spot = alphaSpotPrice(for: input), spot > 0 else {
                return nil
            }

            taoAmount = amount * spot / SubtensorStakingPallet.alphaPriceScale
        }

        let taoDecimal = taoAmount.decimal(assetInfo: chainAsset.assetDisplayInfo)

        return balanceViewModelFactory.balanceFromPrice(taoDecimal, priceData: price).value(for: locale).price
    }

    func alphaSpotPrice(for input: SubtensorUnstakeSetupViewModelInput) -> Balance? {
        if let spot = input.quote?.quote.spotPrice {
            return spot
        }

        guard let subnetInfo = input.target?.subnetInfo else {
            return nil
        }

        let ref = SubtensorSubnetRef(netuid: subnetInfo.netuid, registeredAt: subnetInfo.networkRegisteredAt)

        return input.catalogue?.subnet(for: ref)?.taoPerAlpha
    }

    func createRootNote(for input: SubtensorUnstakeSetupViewModelInput, locale: Locale) -> String? {
        guard input.isRoot else {
            return nil
        }

        let strings = R.string(preferredLanguages: locale.rLanguages).localizable

        return input.holdRemaining == nil
            ? strings.stakingSubtensorUiUnstakeRootNote()
            : strings.stakingSubtensorUiUnstakeRootNoteHold()
    }

    func createFeeWarning(for input: SubtensorUnstakeSetupViewModelInput, locale: Locale) -> String? {
        guard !input.isRoot, let fee = input.fee else {
            return nil
        }

        let feeDecimal = fee.amount.decimal(assetInfo: chainAsset.assetDisplayInfo)
        let feeText = balanceViewModelFactory.amountFromValue(feeDecimal, roundingMode: .up).value(for: locale)

        return R.string(preferredLanguages: locale.rLanguages).localizable.stakingSubtensorUiSellFeeNoteFormat(feeText)
    }

    func createHoldWarning(for input: SubtensorUnstakeSetupViewModelInput, locale: Locale) -> String? {
        guard let remaining = input.holdRemaining else {
            return nil
        }

        let duration = remaining.localizedDaysHoursOrFallbackMinutes(for: locale)
        let unlockDate = Date().addingTimeInterval(remaining)
        let dateText = DateFormatter.shortDateHoursMinutes.value(for: locale).string(from: unlockDate)

        return R.string(preferredLanguages: locale.rLanguages).localizable.stakingSubtensorUiUnstakeRootHoldFormat(
            duration,
            dateText
        )
    }

    func createAction(
        for input: SubtensorUnstakeSetupViewModelInput,
        locale: Locale
    ) -> SubtensorSetupActionViewModel {
        let strings = R.string(preferredLanguages: locale.rLanguages).localizable

        if input.isFullyLocked {
            return SubtensorSetupActionViewModel(
                title: strings.stakingSubtensorUnstakeNothingAvailableTitle(),
                isEnabled: false
            )
        }

        guard input.hasAmount else {
            return SubtensorSetupActionViewModel(title: strings.transferSetupEnterAmount(), isEnabled: false)
        }

        return SubtensorSetupActionViewModel(title: strings.commonContinue(), isEnabled: input.canProceed)
    }

    func createDetails(
        for input: SubtensorUnstakeSetupViewModelInput,
        locale: Locale
    ) -> SubtensorUnstakeDetailsViewModel {
        let tradePanel = createTradePanel(for: input, locale: locale)

        return SubtensorUnstakeDetailsViewModel(
            receive: createReceive(for: input, receive: tradePanel?.receive, locale: locale),
            swapRate: createSwapRate(for: input, swapRate: tradePanel?.swapRate, locale: locale),
            validator: createValidator(for: input),
            networkFee: input.fee.map { formatFee($0, price: input.price, locale: locale) }
        )
    }

    func createTradePanel(
        for input: SubtensorUnstakeSetupViewModelInput,
        locale: Locale
    ) -> SubtensorTradePanelViewModel? {
        guard !input.isRoot, case let .subnet(info, price) = input.target else {
            return nil
        }

        var displayInfo = info
        displayInfo.tokenSymbol = Data(SubtensorSubnetNaming.symbol(for: info.netuid, in: input.catalogue).utf8)

        return quoteViewModelFactory.createTradePanel(
            for: input.quote,
            amountIn: input.amount,
            direction: .sell,
            target: .subnet(info: displayInfo, price: price),
            annualRate: nil,
            taoPrice: input.price,
            locale: locale
        )
    }

    func isQuotePending(for input: SubtensorUnstakeSetupViewModelInput) -> Bool {
        input.target == nil || (input.quote == nil && !input.isQuoteFailed)
    }

    func createReceive(
        for input: SubtensorUnstakeSetupViewModelInput,
        receive: BalanceViewModelProtocol?,
        locale: Locale
    ) -> SubtensorSetupBalanceRowViewModel {
        guard !input.isRoot else {
            return .hidden
        }

        if let receive {
            return .value(BalanceViewModel(amount: receive.amount.isolatedLeftToRight(), price: receive.price))
        }

        if isQuotePending(for: input) {
            return .loading
        }

        let unknown = R.string(preferredLanguages: locale.rLanguages).localizable.stakingSubtensorUiValueUnknown()

        return .value(BalanceViewModel(amount: unknown, price: nil))
    }

    func createSwapRate(
        for input: SubtensorUnstakeSetupViewModelInput,
        swapRate: String?,
        locale: Locale
    ) -> SubtensorSetupRowViewModel {
        guard !input.isRoot else {
            return .hidden
        }

        if let swapRate, !swapRate.isEmpty {
            return .value(swapRate.isolatedLeftToRight())
        }

        if isQuotePending(for: input) {
            return .loading
        }

        return .value(R.string(preferredLanguages: locale.rLanguages).localizable.stakingSubtensorUiValueUnknown())
    }

    func createValidator(for input: SubtensorUnstakeSetupViewModelInput) -> SubtensorSetupValidatorViewModel {
        guard
            let hotkey = input.primaryHotkey,
            let address = try? hotkey.toAddress(using: chainAsset.chain.chainFormat) else {
            return .loading
        }

        let name = input.validatorName ?? address.mediumTruncated
        let viewModel = displayAddressFactory.createViewModel(
            from: DisplayAddress(address: address, username: input.validatorName ?? "")
        )

        return .selected(
            DisplayAddressViewModel(address: viewModel.address, name: name, imageViewModel: viewModel.imageViewModel),
            accessory: .info
        )
    }
}

private extension String {
    func isolatedLeftToRight() -> String {
        "\u{2066}\(self)\u{2069}"
    }
}
