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

        let details: SubtensorSetupDetailsViewModel
        if case let .quickPick(order) = input.mode {
            details = .selection(createSelection(for: input, order: order, locale: locale))
        } else {
            details = input.mode.isRootLane
                ? .root(createRootDetails(for: input, locale: locale))
                : .subnet(createSubnetDetails(for: input, locale: locale))
        }

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
            caption: createCaption(for: input, locale: locale),
            browseTitle: input.mode.isLocked ? nil : strings.stakingSubtensorQuickSeeAll(),
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

extension SubtensorStakingSetupViewModelFactory {
    func createTitle(for input: SubtensorStakingSetupViewModelInput, locale: Locale) -> String {
        let strings = R.string(preferredLanguages: locale.rLanguages).localizable

        switch input.mode {
        case .rootDetails:
            return input.rootEntryPresentation == .quickPickRoot || input.quickPickOrder != nil
                ? strings.stakingSubtensorUiEarnTitle() : strings.stakingSubtensorUiStakeToRoot()
        case .addStake:
            return strings.stakingSubtensorUiAddStakeRootTitle()
        case .quickPick, .subnetPick:
            return strings.stakingSubtensorUiEarnTitle()
        case let .buyMore(position):
            let subnetTitle = SubtensorSubnetNaming.title(
                for: position.netuid,
                in: input.matchingCatalogue,
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
        let strings = R.string(preferredLanguages: locale.rLanguages).localizable
        let compact = createValidator(for: input, locale: locale)
        let name: String?
        let icon: ImageViewModelProtocol?
        switch compact {
        case .loading: name = nil; icon = nil
        case let .unselected(title): name = title; icon = nil
        case let .selected(display): name = display.name ?? display.address; icon = display.imageViewModel
        }
        let annualRate = input.subnetData.annualRate
        let validator: SubtensorSetupRootValidatorViewModel
        if case .addStake = input.mode {
            validator = .rows(
                validator: StackCellViewModel(details: name ?? "", imageViewModel: icon),
                apy: SubtensorApyFormatter.text(for: annualRate, style: .paidInTao, locale: locale)
            )
        } else {
            validator = .card(SubtensorValidatorCardViewModel(
                icon: icon, name: name, subtitle: strings.stakingCommonValidator(),
                rate: .value(SubtensorApyFormatter.text(for: annualRate, style: .bare, locale: locale)),
                rateCaption: strings.stakingSubtensorV22EstApy()
            ))
        }
        return SubtensorSetupRootViewModel(
            icon: AssetIconViewModelFactory().createAssetIconViewModel(from: chainAsset.assetDisplayInfo),
            validator: validator,
            compactValidator: compact,
            compactRate: SubtensorApyFormatter.text(for: annualRate, style: .leading, locale: locale),
            isQuickPick: input.rootEntryPresentation == .quickPickRoot || input.quickPickOrder != nil,
            networkFee: createNetworkFee(for: input, locale: locale)
        )
    }

    func createValidator(
        for input: SubtensorStakingSetupViewModelInput,
        locale: Locale
    ) -> SubtensorSetupValidatorViewModel {
        let selectTitle = R.string(preferredLanguages: locale.rLanguages).localizable.stakingSubtensorSelectValidator()

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
                )
            )
        }
    }

    func createCaption(for input: SubtensorStakingSetupViewModelInput, locale: Locale) -> String? {
        let strings = R.string(preferredLanguages: locale.rLanguages).localizable

        if input.amountState == .noTao {
            return input.mode.isRootLane ? strings.stakingSubtensorUiGetTaoRootCaption() : nil
        }

        guard case .addStake = input.mode else {
            return nil
        }

        return createAddStakeCaption(for: input, locale: locale)
    }

    func createAddStakeCaption(for input: SubtensorStakingSetupViewModelInput, locale: Locale) -> String? {
        let strings = R.string(preferredLanguages: locale.rLanguages).localizable

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
        let showsEnterAmount = !hasAmount && input.amountState != .noTao

        return SubtensorSetupActionViewModel(
            title: showsEnterAmount ? strings.transferSetupEnterAmount() : strings.commonContinue(),
            isEnabled: input.canProceed
        )
    }
}
