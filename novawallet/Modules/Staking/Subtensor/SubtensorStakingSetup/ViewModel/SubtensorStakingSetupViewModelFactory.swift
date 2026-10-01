import BigInt
import Foundation

final class SubtensorStakingSetupViewModelFactory {
    let chainAsset: ChainAsset
    let balanceViewModelFactory: BalanceViewModelFactoryProtocol
    let quoteViewModelFactory: SubtensorQuoteViewModelFactoryProtocol
    let displayAddressFactory: DisplayAddressViewModelFactoryProtocol
    let iconFactory: SubtensorSubnetIconFactoryProtocol
    let costBasisViewModelFactory: SubtensorCostBasisViewModelFactory

    init(
        chainAsset: ChainAsset,
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        quoteViewModelFactory: SubtensorQuoteViewModelFactoryProtocol,
        displayAddressFactory: DisplayAddressViewModelFactoryProtocol = DisplayAddressViewModelFactory(),
        iconFactory: SubtensorSubnetIconFactoryProtocol = SubtensorSubnetIconViewModelFactory()
    ) {
        self.chainAsset = chainAsset
        self.balanceViewModelFactory = balanceViewModelFactory
        self.quoteViewModelFactory = quoteViewModelFactory
        self.displayAddressFactory = displayAddressFactory
        self.iconFactory = iconFactory
        costBasisViewModelFactory = SubtensorCostBasisViewModelFactory(
            taoInfo: chainAsset.assetDisplayInfo,
            balanceViewModelFactory: balanceViewModelFactory
        )
    }

    func createViewModel(
        for input: SubtensorStakingSetupViewModelInput,
        locale: Locale
    ) -> SubtensorStakingSetupViewModel {
        let strings = R.string(preferredLanguages: locale.rLanguages).localizable

        let details: SubtensorSetupDetailsViewModel = input.mode.isRootLane
            ? .root(createRootDetails(for: input, locale: locale))
            : .subnet(createSubnetDetails(for: input, locale: locale))

        let amountTitle: String

        if case .buyMore = input.mode {
            amountTitle = strings.swapsSetupAssetSelectPayTitle()
        } else {
            amountTitle = strings.stakingSubtensorUiYouStake()
        }

        return SubtensorStakingSetupViewModel(
            title: createTitle(for: input, locale: locale),
            amountTitle: amountTitle,
            maxAmount: input.maxAmount.map { formatAmount($0, locale: locale) },
            hasSettings: input.mode.hasSettings,
            getTao: createGetTao(for: input, locale: locale),
            reserveWarning: createReserveWarning(for: input, locale: locale),
            details: details,
            holdWarning: createHoldWarning(for: input, locale: locale),
            caption: createCaption(for: input, locale: locale),
            action: createAction(for: input, locale: locale)
        )
    }
}

extension SubtensorStakingSetupViewModelFactory {
    func formatAmount(_ amount: Balance, locale: Locale) -> String {
        let decimal = amount.decimal(assetInfo: chainAsset.assetDisplayInfo)

        return balanceViewModelFactory.amountFromValue(decimal).value(for: locale)
    }

    func createNetworkFee(
        for input: SubtensorStakingSetupViewModelInput,
        locale: Locale
    ) -> BalanceViewModelProtocol? {
        guard let fee = input.fee else {
            return nil
        }

        let feeDecimal = fee.amount.decimal(assetInfo: chainAsset.assetDisplayInfo)

        return balanceViewModelFactory.balanceFromPrice(
            feeDecimal,
            priceData: input.price,
            roundingMode: .up
        ).value(for: locale)
    }
}

private extension SubtensorStakingSetupViewModelFactory {
    func createTitle(for input: SubtensorStakingSetupViewModelInput, locale: Locale) -> String {
        let strings = R.string(preferredLanguages: locale.rLanguages).localizable

        switch input.mode {
        case .rootDetails:
            return strings.stakingSubtensorUiStakeToRoot()
        case .addStake:
            return strings.stakingSubtensorUiAddStakeRootTitle()
        case .subnetPick:
            return strings.stakingSubtensorBannerTitle()
        case let .buyMore(position):
            let subnetTitle = SubtensorSubnetNaming.title(
                for: position.netuid,
                in: input.subnetData.catalogue,
                locale: locale
            )

            return strings.stakingSubtensorUiBuyMoreFormat(subnetTitle)
        }
    }

    func createGetTao(
        for input: SubtensorStakingSetupViewModelInput,
        locale: Locale
    ) -> SubtensorGetTaoViewModel? {
        guard input.amountState == .noTao else {
            return nil
        }

        let strings = R.string(preferredLanguages: locale.rLanguages).localizable
        let balance = formatAmount(input.transferable ?? 0, locale: locale)

        return SubtensorGetTaoViewModel(
            title: strings.stakingSubtensorUiGetTaoTitle(),
            message: strings.stakingSubtensorUiGetTaoMessage(balance),
            action: strings.stakingSubtensorUiGetTaoAction()
        )
    }

    func createReserveWarning(for input: SubtensorStakingSetupViewModelInput, locale: Locale) -> String? {
        guard input.amountState == .insufficient else {
            return nil
        }

        let reserve = formatAmount(SubtensorNovaFeeConstants.feeReserve, locale: locale)

        return R.string(preferredLanguages: locale.rLanguages).localizable.stakingSubtensorUiFeeReserveFormat(
            reserve,
            reserve
        )
    }

    func createRootDetails(
        for input: SubtensorStakingSetupViewModelInput,
        locale: Locale
    ) -> SubtensorSetupRootViewModel {
        SubtensorSetupRootViewModel(
            validator: createValidator(for: input, locale: locale),
            apy: createRootApy(for: input, locale: locale),
            networkFee: createNetworkFee(for: input, locale: locale)
        )
    }

    func createValidator(
        for input: SubtensorStakingSetupViewModelInput,
        locale: Locale
    ) -> SubtensorSetupValidatorViewModel {
        let selectTitle = R.string(preferredLanguages: locale.rLanguages).localizable.stakingSubtensorSelectValidator()
        let accessory: SubtensorSetupValidatorAccessory = input.mode.isLocked ? .info : .chevron

        switch input.validator {
        case .pending:
            return .loading
        case .none:
            return .unselected(title: selectTitle)
        case let .selected(validator):
            guard let address = try? validator.hotkey.toAddress(using: chainAsset.chain.chainFormat) else {
                return .unselected(title: selectTitle)
            }

            let displayAddress = DisplayAddress(address: address, username: validator.name ?? "")
            let viewModel = displayAddressFactory.createViewModel(from: displayAddress)

            return .selected(
                DisplayAddressViewModel(
                    address: viewModel.address,
                    name: validator.name ?? address.mediumTruncated,
                    imageViewModel: viewModel.imageViewModel
                ),
                accessory: accessory
            )
        }
    }

    func createRootApy(for input: SubtensorStakingSetupViewModelInput, locale: Locale) -> SubtensorSetupRowViewModel {
        guard input.isRootRateLoaded else {
            return .loading
        }

        guard let rootRate = input.rootRate else {
            return .hidden
        }

        return .value(SubtensorApyFormatter.text(for: rootRate, style: .paidInTao, locale: locale))
    }

    func createHoldWarning(for input: SubtensorStakingSetupViewModelInput, locale: Locale) -> String? {
        guard let remaining = input.holdRemaining else {
            return nil
        }

        let duration = remaining.localizedDaysHoursOrFallbackMinutes(for: locale)

        return R.string(preferredLanguages: locale.rLanguages).localizable.stakingSubtensorUiHoldAddMessage(duration)
    }

    func createCaption(for input: SubtensorStakingSetupViewModelInput, locale: Locale) -> String? {
        let strings = R.string(preferredLanguages: locale.rLanguages).localizable

        if input.amountState == .noTao {
            return strings.stakingSubtensorUiGetTaoCaption()
        }

        switch input.mode {
        case .rootDetails:
            return nil
        case .addStake:
            return createAddStakeCaption(for: input, locale: locale)
        case .subnetPick, .buyMore:
            return strings.stakingSubtensorUiSafetyNote()
        }
    }

    func createAddStakeCaption(for input: SubtensorStakingSetupViewModelInput, locale: Locale) -> String? {
        let strings = R.string(preferredLanguages: locale.rLanguages).localizable

        if let remaining = input.holdRemaining {
            let unlockDate = Date().addingTimeInterval(remaining)
            let dateText = DateFormatter.shortDateHoursMinutes.value(for: locale).string(from: unlockDate)

            return strings.stakingSubtensorUiHoldAddAvailableFormat(dateText)
        }

        guard
            let positionStake = input.positionStake, positionStake > 0,
            let validator = input.validator.validator,
            let address = try? validator.hotkey.toAddress(using: chainAsset.chain.chainFormat) else {
            return nil
        }

        return strings.stakingSubtensorUiAddsToFormat(
            formatAmount(positionStake, locale: locale),
            validator.name ?? address.mediumTruncated
        )
    }

    func createAction(
        for input: SubtensorStakingSetupViewModelInput,
        locale: Locale
    ) -> SubtensorSetupActionViewModel {
        let strings = R.string(preferredLanguages: locale.rLanguages).localizable

        if input.needsValidatorPick, input.amountState != .noTao {
            return SubtensorSetupActionViewModel(title: strings.stakingSubtensorSelectValidator(), isEnabled: true)
        }

        let hasAmount = (input.amount ?? 0) > 0
        let showsEnterAmount = !hasAmount && input.amountState != .noTao && !input.isHoldActive

        return SubtensorSetupActionViewModel(
            title: showsEnterAmount ? strings.transferSetupEnterAmount() : strings.commonContinue(),
            isEnabled: input.canProceed
        )
    }
}
