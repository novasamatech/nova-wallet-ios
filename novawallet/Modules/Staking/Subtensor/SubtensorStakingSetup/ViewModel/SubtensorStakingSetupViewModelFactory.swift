import BigInt
import Foundation

struct SubtensorStakingSetupViewModel {
    let title: String
    let maxAmount: String?
    let getTao: SubtensorGetTaoViewModel?
    let reserveWarning: String?
    let validator: SubtensorSetupValidatorViewModel
    let apy: SubtensorSetupRowViewModel
    let receive: SubtensorSetupRowViewModel
    let swapRate: SubtensorSetupRowViewModel
    let slippage: SubtensorSetupRowViewModel
    let networkFee: BalanceViewModelProtocol?
    let caption: String?
    let action: SubtensorSetupActionViewModel
}

struct SubtensorGetTaoViewModel: Equatable {
    let title: String
    let message: String
    let action: String
}

struct SubtensorSetupActionViewModel: Equatable {
    let title: String
    let isEnabled: Bool
}

enum SubtensorSetupRowViewModel: Equatable {
    case hidden
    case loading
    case value(String)
}

enum SubtensorSetupValidatorViewModel {
    case loading
    case unselected(title: String, canSelect: Bool)
    case selected(DisplayAddressViewModel, canSelect: Bool)

    var isLoading: Bool {
        if case .loading = self {
            return true
        }

        return false
    }
}

struct SubtensorSetupValidator: Equatable {
    let hotkey: AccountId
    let name: String?
}

enum SubtensorSetupValidatorState: Equatable {
    case pending
    case none
    case selected(SubtensorSetupValidator)

    var validator: SubtensorSetupValidator? {
        if case let .selected(validator) = self {
            return validator
        }

        return nil
    }
}

enum SubtensorSetupAmountState: Equatable {
    case loading
    case noTao
    case insufficient
    case sufficient

    init(maxAmount: Balance?, amount: Balance?) {
        guard let maxAmount else {
            self = .loading
            return
        }

        if maxAmount == 0 {
            self = .noTao
        } else if let amount, amount > maxAmount {
            self = .insufficient
        } else {
            self = .sufficient
        }
    }
}

struct SubtensorStakingSetupViewModelInput {
    let mode: SubtensorStakingSetupMode
    let target: SubtensorStakeTarget?
    let catalogue: SubtensorSubnetCatalogue?
    let transferable: Balance?
    let maxAmount: Balance?
    let amount: Balance?
    let validator: SubtensorSetupValidatorState
    let rootRate: Decimal?
    let isRootRateLoaded: Bool
    let fee: ExtrinsicFeeProtocol?
    let price: PriceData?
    let quote: SubtensorTradeQuote?
    let slippage: BigRational

    var amountState: SubtensorSetupAmountState {
        SubtensorSetupAmountState(maxAmount: maxAmount, amount: amount)
    }

    var canProceed: Bool {
        guard
            amountState == .sufficient,
            let amount, amount > 0,
            validator.validator != nil,
            fee != nil,
            target != nil else {
            return false
        }

        return mode.isRootLane || quote != nil
    }
}

final class SubtensorStakingSetupViewModelFactory {
    let chainAsset: ChainAsset
    let balanceViewModelFactory: BalanceViewModelFactoryProtocol
    let quoteViewModelFactory: SubtensorQuoteViewModelFactoryProtocol
    let displayAddressFactory: DisplayAddressViewModelFactoryProtocol

    init(
        chainAsset: ChainAsset,
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        quoteViewModelFactory: SubtensorQuoteViewModelFactoryProtocol,
        displayAddressFactory: DisplayAddressViewModelFactoryProtocol = DisplayAddressViewModelFactory()
    ) {
        self.chainAsset = chainAsset
        self.balanceViewModelFactory = balanceViewModelFactory
        self.quoteViewModelFactory = quoteViewModelFactory
        self.displayAddressFactory = displayAddressFactory
    }

    func createViewModel(
        for input: SubtensorStakingSetupViewModelInput,
        locale: Locale
    ) -> SubtensorStakingSetupViewModel {
        let tradePanel = createTradePanel(for: input, locale: locale)

        return SubtensorStakingSetupViewModel(
            title: createTitle(for: input, locale: locale),
            maxAmount: input.maxAmount.map { formatAmount($0, locale: locale) },
            getTao: createGetTao(for: input, locale: locale),
            reserveWarning: createReserveWarning(for: input, locale: locale),
            validator: createValidator(for: input, locale: locale),
            apy: createApy(for: input, locale: locale),
            receive: createTradeRow(for: input, value: tradePanel?.receive?.amount, locale: locale),
            swapRate: createTradeRow(for: input, value: tradePanel?.swapRate, locale: locale),
            slippage: createSlippage(for: input, locale: locale),
            networkFee: createNetworkFee(for: input, locale: locale),
            caption: createCaption(for: input, locale: locale),
            action: createAction(for: input, locale: locale)
        )
    }
}

private extension SubtensorStakingSetupViewModelFactory {
    func formatAmount(_ amount: Balance, locale: Locale) -> String {
        let decimal = amount.decimal(assetInfo: chainAsset.assetDisplayInfo)

        return balanceViewModelFactory.amountFromValue(decimal).value(for: locale)
    }

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
                in: input.catalogue,
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

    func createValidator(
        for input: SubtensorStakingSetupViewModelInput,
        locale: Locale
    ) -> SubtensorSetupValidatorViewModel {
        let canSelect = !input.mode.isLocked
        let selectTitle = R.string(preferredLanguages: locale.rLanguages).localizable.stakingSubtensorSelectValidator()

        switch input.validator {
        case .pending:
            return .loading
        case .none:
            return .unselected(title: selectTitle, canSelect: canSelect)
        case let .selected(validator):
            guard let address = try? validator.hotkey.toAddress(using: chainAsset.chain.chainFormat) else {
                return .unselected(title: selectTitle, canSelect: canSelect)
            }

            let displayAddress = DisplayAddress(address: address, username: validator.name ?? "")
            let viewModel = displayAddressFactory.createViewModel(from: displayAddress)

            return .selected(
                DisplayAddressViewModel(
                    address: viewModel.address,
                    name: validator.name ?? address.mediumTruncated,
                    imageViewModel: viewModel.imageViewModel
                ),
                canSelect: canSelect
            )
        }
    }

    func createApy(for input: SubtensorStakingSetupViewModelInput, locale: Locale) -> SubtensorSetupRowViewModel {
        guard input.mode.isRootLane else {
            return .hidden
        }

        guard input.isRootRateLoaded else {
            return .loading
        }

        guard let rootRate = input.rootRate else {
            return .hidden
        }

        return .value(SubtensorApyFormatter.text(for: rootRate, style: .paidInTao, locale: locale))
    }

    func createTradePanel(
        for input: SubtensorStakingSetupViewModelInput,
        locale: Locale
    ) -> SubtensorTradePanelViewModel? {
        guard let target = input.target else {
            return nil
        }

        return quoteViewModelFactory.createTradePanel(
            for: input.quote,
            amountIn: input.amount,
            direction: .buy,
            target: target,
            annualRate: nil,
            taoPrice: input.price,
            locale: locale
        )
    }

    func createTradeRow(
        for input: SubtensorStakingSetupViewModelInput,
        value: String?,
        locale: Locale
    ) -> SubtensorSetupRowViewModel {
        guard !input.mode.isRootLane else {
            return .hidden
        }

        guard input.target != nil else {
            return .loading
        }

        let unknown = R.string(preferredLanguages: locale.rLanguages).localizable.stakingSubtensorUiValueUnknown()

        return .value(value ?? unknown)
    }

    func createSlippage(for input: SubtensorStakingSetupViewModelInput, locale: Locale) -> SubtensorSetupRowViewModel {
        guard
            !input.mode.isRootLane,
            let slippage = quoteViewModelFactory.createSlippageViewModel(for: input.slippage, locale: locale) else {
            return .hidden
        }

        return .value(slippage)
    }

    func createNetworkFee(
        for input: SubtensorStakingSetupViewModelInput,
        locale: Locale
    ) -> BalanceViewModelProtocol? {
        guard let fee = input.fee else {
            return nil
        }

        let feeDecimal = fee.amount.decimal(assetInfo: chainAsset.assetDisplayInfo)

        return balanceViewModelFactory.balanceFromPrice(feeDecimal, priceData: input.price).value(for: locale)
    }

    func createCaption(for input: SubtensorStakingSetupViewModelInput, locale: Locale) -> String? {
        if input.amountState == .noTao {
            return R.string(preferredLanguages: locale.rLanguages).localizable.stakingSubtensorUiGetTaoCaption()
        }

        return input.mode.isRootLane ? nil : quoteViewModelFactory.novaFeeDisclosure(locale: locale)
    }

    func createAction(
        for input: SubtensorStakingSetupViewModelInput,
        locale: Locale
    ) -> SubtensorSetupActionViewModel {
        let strings = R.string(preferredLanguages: locale.rLanguages).localizable

        let hasAmount = (input.amount ?? 0) > 0
        let showsEnterAmount = !hasAmount && input.amountState != .noTao

        return SubtensorSetupActionViewModel(
            title: showsEnterAmount ? strings.transferSetupEnterAmount() : strings.commonContinue(),
            isEnabled: input.canProceed
        )
    }
}
