import BigInt
import Foundation

struct SubtensorStakingSetupViewModel {
    let title: String
    let amountTitle: String
    let maxAmount: String?
    let hasSettings: Bool
    let getTao: SubtensorGetTaoViewModel?
    let reserveWarning: String?
    let failure: WarningView.Model?
    let details: SubtensorSetupDetailsViewModel
    let caption: String?
    let browseTitle: String?
    let action: SubtensorSetupActionViewModel
}

struct SubtensorSetupSelectionViewModel {
    let section: String
    let caption: String
}

enum SubtensorSetupDetailsViewModel {
    case selection(SubtensorSetupSelectionViewModel)
    case root(SubtensorSetupRootViewModel)
    case subnet(SubtensorSetupSubnetViewModel)

    var selection: SubtensorSetupSelectionViewModel? {
        if case let .selection(viewModel) = self {
            return viewModel
        }

        return nil
    }
}

enum SubtensorRootEntryPresentation {
    case standard
    case quickPickRoot
}

enum SubtensorSetupRootValidatorViewModel {
    case card(SubtensorValidatorCardViewModel)
    case rows(validator: StackCellViewModel, apy: String)
}

struct SubtensorSetupRootViewModel {
    let validator: SubtensorSetupRootValidatorViewModel
    let pickCard: SubtensorPickCardViewModel?
    let networkFee: BalanceViewModelProtocol?
}

struct SubtensorSetupSubnetViewModel {
    let sectionTitle: String
    let card: SubtensorPickCardViewModel
    let avgBuyPrice: SubtensorRowState<SubtensorCostBasisValueViewModel>
}

struct SubtensorPickCardViewModel {
    let validator: SubtensorSetupValidatorViewModel
    let validatorRate: String?
    let isValidatorEditable: Bool
    let browseTitle: String?
    let header: SubtensorPickCardHeaderViewModel?
    let chips: [String]
    let receive: SubtensorRowState<String>
    let swapRate: SubtensorRowState<String>
    let networkFee: BalanceViewModelProtocol?
    let isRoot: Bool
}

struct SubtensorPickCardHeaderViewModel {
    let icon: ImageViewModelProtocol
    let title: String
    let isSelectable: Bool
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

enum SubtensorRowState<Value> {
    case hidden
    case loading
    case value(Value)
}

extension SubtensorRowState: Equatable where Value: Equatable {}

extension SubtensorRowState where Value == String {
    static func trade(_ value: String?, isPending: Bool, locale: Locale) -> SubtensorRowState<String> {
        if let value {
            return .value(SubtensorSubnetNaming.isolatedLeftToRight(value))
        }

        return isPending ? .loading : .value(.subtensorUnknown(for: locale))
    }
}

enum SubtensorSetupValidatorViewModel {
    case loading
    case unselected(title: String)
    case selected(DisplayAddressViewModel)

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

struct SubtensorSetupSubnetData {
    let catalogue: SubtensorSubnetCatalogue?
    let subnetLogos: SubtensorSubnetLogos?
    let rankedSubnet: SubtensorRankedSubnet?
    let annualRate: Decimal?
    let isRateResolved: Bool
    let isQuoteFailed: Bool
    let costBasis: SubtensorCostBasisState
    let blockTime: BlockTime?
}

struct SubtensorStakingSetupViewModelInput {
    let mode: SubtensorStakingSetupMode
    let target: SubtensorStakeTarget?
    let subnetData: SubtensorSetupSubnetData
    let transferable: Balance?
    let maxAmount: Balance?
    let amount: Balance?
    let validator: SubtensorSetupValidatorState
    let fee: ExtrinsicFeeProtocol?
    let price: PriceData?
    let quote: SubtensorTradeQuote?
    let positionStake: Balance?
    var quickPickOrder: SubtensorQuickPickOrder?
    var selectionFailed = false
    var presetError: Error?
    var rootEntryPresentation: SubtensorRootEntryPresentation = .standard

    // A reused netuid can still have metadata cached for its previous registration.
    var matchingCatalogue: SubtensorSubnetCatalogue? {
        guard let ref = target?.subnetRef, let subnet = subnetData.catalogue?.subnet(for: ref) else { return nil }
        return SubtensorSubnetCatalogue(subnets: [subnet])
    }

    var amountState: SubtensorSetupAmountState {
        let state: SubtensorSetupAmountState = transferable == 0
            ? .noTao : SubtensorSetupAmountState(maxAmount: maxAmount, amount: amount)

        guard state == .noTao, mode.isLocked else {
            return state
        }

        return (amount ?? 0) > 0 ? .insufficient : .sufficient
    }

    var needsValidatorPick: Bool {
        if case .subnetPick = mode, validator == .none {
            return true
        }

        return false
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

        return mode.isRootLane || quote?.amountIn == amount
    }
}
