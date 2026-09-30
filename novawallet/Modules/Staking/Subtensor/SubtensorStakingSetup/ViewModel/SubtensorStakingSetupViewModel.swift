import BigInt
import Foundation

struct SubtensorStakingSetupViewModel {
    let title: String
    let amountTitle: String
    let maxAmount: String?
    let hasSettings: Bool
    let getTao: SubtensorGetTaoViewModel?
    let reserveWarning: String?
    let details: SubtensorSetupDetailsViewModel
    let holdWarning: String?
    let caption: String?
    let action: SubtensorSetupActionViewModel
}

enum SubtensorSetupDetailsViewModel {
    case root(SubtensorSetupRootViewModel)
    case subnet(SubtensorSetupSubnetViewModel)
}

struct SubtensorSetupRootViewModel {
    let validator: SubtensorSetupValidatorViewModel
    let apy: SubtensorSetupRowViewModel
    let networkFee: BalanceViewModelProtocol?
}

struct SubtensorSetupSubnetViewModel {
    let sectionTitle: String
    let card: SubtensorPickCardViewModel
    let feeDisclosure: String
}

struct SubtensorPickCardViewModel {
    let header: SubtensorPickCardHeaderViewModel?
    let chips: [String]
    let receive: SubtensorSetupRowViewModel
    let swapRate: SubtensorSetupRowViewModel
    let earnPerMonth: SubtensorSetupBalanceRowViewModel
    let networkFee: BalanceViewModelProtocol?
    let footer: String?
}

struct SubtensorPickCardHeaderViewModel {
    let icon: ImageViewModelProtocol
    let title: String
    let apy: String?
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

enum SubtensorSetupRowViewModel: Equatable {
    case hidden
    case loading
    case value(String)
}

enum SubtensorSetupBalanceRowViewModel {
    case hidden
    case loading
    case value(BalanceViewModelProtocol)
}

enum SubtensorSetupValidatorAccessory: Equatable {
    case chevron
    case info
}

enum SubtensorSetupValidatorViewModel {
    case loading
    case unselected(title: String)
    case selected(DisplayAddressViewModel, accessory: SubtensorSetupValidatorAccessory)

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
    let isCatalogueLoaded: Bool
    let subnetLogos: SubtensorSubnetLogos?
    let rankedSubnet: SubtensorRankedSubnet?
    let annualRate: Decimal?
    let isYieldsLoaded: Bool
    let isQuoteFailed: Bool
}

struct SubtensorStakingSetupViewModelInput {
    let mode: SubtensorStakingSetupMode
    let target: SubtensorStakeTarget?
    let subnetData: SubtensorSetupSubnetData
    let transferable: Balance?
    let maxAmount: Balance?
    let amount: Balance?
    let validator: SubtensorSetupValidatorState
    let rootRate: Decimal?
    let isRootRateLoaded: Bool
    let fee: ExtrinsicFeeProtocol?
    let price: PriceData?
    let quote: SubtensorTradeQuote?
    let positionStake: Balance?
    let holdRemaining: TimeInterval?

    var amountState: SubtensorSetupAmountState {
        let state = SubtensorSetupAmountState(maxAmount: maxAmount, amount: amount)

        guard state == .noTao, mode.isLocked else {
            return state
        }

        return (amount ?? 0) > 0 ? .insufficient : .sufficient
    }

    var isHoldActive: Bool {
        holdRemaining != nil
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
            !isHoldActive,
            let amount, amount > 0,
            validator.validator != nil,
            fee != nil,
            target != nil else {
            return false
        }

        return mode.isRootLane || quote?.amountIn == amount
    }
}
