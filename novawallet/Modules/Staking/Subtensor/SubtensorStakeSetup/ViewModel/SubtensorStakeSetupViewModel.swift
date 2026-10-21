import BigInt
import Foundation

struct SubtensorStakeSetupViewModel {
    let title: String
    let amountTitle: String
    let maxAmount: String?
    let hasSettings: Bool
    let getTao: SubtensorGetTaoViewModel?
    let reserveWarning: String?
    let failure: WarningView.Model?
    let details: SubtensorStakeSetupDetailsViewModel
    let caption: String?
    let browseTitle: String?
    let action: SubtensorSetupActionViewModel
}

struct SubtensorStakeSetupSelectionViewModel {
    let section: String
    let caption: String
}

enum SubtensorStakeSetupDetailsViewModel {
    case selection(SubtensorStakeSetupSelectionViewModel)
    case root(SubtensorStakeSetupRootViewModel)
    case subnet(SubtensorStakeSetupSubnetViewModel)

    var selection: SubtensorStakeSetupSelectionViewModel? {
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

enum SubtensorStakeSetupRootValidatorViewModel {
    case card(SubtensorValidatorCardViewModel)
    case rows(validator: StackCellViewModel, apy: String)
}

struct SubtensorStakeSetupRootViewModel {
    let validator: SubtensorStakeSetupRootValidatorViewModel
    let pickCard: SubtensorPickCardViewModel?
    let networkFee: BalanceViewModelProtocol?
}

struct SubtensorStakeSetupSubnetViewModel {
    let sectionTitle: String
    let card: SubtensorPickCardViewModel
    let avgBuyPrice: SubtensorRowState<SubtensorCostBasisValueViewModel>
}

struct SubtensorPickCardViewModel {
    let validator: SubtensorSetupValidatorViewModel
    let validatorRate: String?
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

struct SubtensorStakeSetupValidator: Equatable {
    let hotkey: AccountId
    let name: String?
}

enum SubtensorStakeSetupValidatorState: Equatable {
    case pending
    case none
    case selected(SubtensorStakeSetupValidator)

    var validator: SubtensorStakeSetupValidator? {
        if case let .selected(validator) = self {
            return validator
        }

        return nil
    }
}

enum SubtensorStakeSetupAmountState: Equatable {
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

struct SubtensorStakeSetupSubnetData {
    let catalogue: SubtensorSubnetCatalogue?
    let subnetLogos: SubtensorSubnetLogos?
    let rankedSubnet: SubtensorRankedSubnet?
    let annualRate: Decimal?
    let isRateResolved: Bool
    let isQuoteFailed: Bool
    let costBasis: SubtensorCostBasisState
    let blockTime: BlockTime?
}

struct SubtensorStakeSetupViewModelInput {
    let mode: SubtensorStakeSetupMode
    let target: SubtensorStakeTarget?
    let subnetData: SubtensorStakeSetupSubnetData
    let transferable: Balance?
    let maxAmount: Balance?
    let amount: Balance?
    let validator: SubtensorStakeSetupValidatorState
    let fee: ExtrinsicFeeProtocol?
    let price: PriceData?
    let quote: SubtensorTradeQuote?
    let positionStake: Balance?
    var quickPickOrder: SubtensorQuickPickOrder?
    var selectionFailed = false
    var presetError: Error?
    var rootEntryPresentation: SubtensorRootEntryPresentation = .standard
    var isLockedValidatorPending = false

    // A reused netuid can still have metadata cached for its previous registration.
    var matchingCatalogue: SubtensorSubnetCatalogue? {
        guard let ref = target?.subnetRef, let subnet = subnetData.catalogue?.subnet(for: ref) else { return nil }
        return SubtensorSubnetCatalogue(subnets: [subnet])
    }

    var amountState: SubtensorStakeSetupAmountState {
        let state: SubtensorStakeSetupAmountState = transferable == 0
            ? .noTao : SubtensorStakeSetupAmountState(maxAmount: maxAmount, amount: amount)

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
            !isLockedValidatorPending,
            fee != nil,
            target != nil else {
            return false
        }

        return mode.isRootLane || quote?.amountIn == amount
    }
}
