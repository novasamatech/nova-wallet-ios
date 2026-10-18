import BigInt
import Foundation

struct SubtensorUnstakeSetupViewModel {
    let title: String
    let header: SubtensorUnstakeHeaderViewModel
    let inputPrice: String?
    let isInputEnabled: Bool
    let details: SubtensorUnstakeDetailsViewModel
    let note: String?
    let feeWarning: String?
    let holdWarning: String?
    let action: SubtensorSetupActionViewModel
}

struct SubtensorUnstakeHeaderViewModel {
    let title: String
    let prefix: String
    let value: String?
    let link: String?
    let isEnabled: Bool
}

struct SubtensorUnstakeDetailsViewModel {
    let receive: SubtensorRowState<BalanceViewModelProtocol>
    let swapRate: SubtensorRowState<String>
    let avgBuyPrice: SubtensorRowState<SubtensorCostBasisValueViewModel>
    let earned: SubtensorRowState<SubtensorCostBasisValueViewModel>
    let validator: SubtensorSetupValidatorViewModel
    let networkFee: BalanceViewModelProtocol?
}

struct SubtensorUnstakeSetupViewModelInput {
    let netuid: UInt16
    let target: SubtensorStakeTarget?
    let catalogue: SubtensorSubnetCatalogue?
    let basis: SubtensorGroupUnstakeBasis?
    let maxAmount: Balance?
    let amount: Balance?
    let primaryHotkey: AccountId?
    let validatorName: String?
    let fee: ExtrinsicFeeProtocol?
    let price: PriceData?
    let quote: SubtensorTradeQuote?
    let isQuoteFailed: Bool
    let holdRemainingBlocks: UInt64?
    let blockTime: BlockTime?
    let costBasis: SubtensorCostBasisState

    var isRoot: Bool {
        netuid == SubtensorStakingPallet.rootNetuid
    }

    var isFullyLocked: Bool {
        guard let basis else {
            return false
        }

        return basis.available == 0
    }

    var hasAmount: Bool {
        (amount ?? 0) > 0
    }

    var canProceed: Bool {
        basis != nil && target != nil && hasAmount && !isFullyLocked && holdRemainingBlocks == nil &&
            (isRoot || quote?.amountIn == amount)
    }
}
