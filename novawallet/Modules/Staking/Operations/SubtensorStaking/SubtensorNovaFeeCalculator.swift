import BigInt
import Foundation

struct SubtensorNovaFeeCalculator {
    let beneficiary: AccountId?

    init(beneficiary: AccountId? = SubtensorNovaFeeCalculator.defaultBeneficiary) {
        self.beneficiary = beneficiary
    }
}

extension SubtensorNovaFeeCalculator {
    static var defaultBeneficiary: AccountId? {
        guard
            let address = SubtensorNovaFeeConstants.beneficiaryAddress,
            let accountId = try? address.toAccountId(),
            accountId.count == SubstrateConstants.accountIdLength else {
            return nil
        }

        return accountId
    }

    static func minimumTaoOut(alpha: Balance, limitPrice: Balance) throws -> Balance {
        try SubtensorStakingPallet.ensureU64Amount(alpha)
        try SubtensorStakingPallet.ensureU64Amount(limitPrice)

        let minimumTaoOut = alpha * limitPrice / SubtensorStakingPallet.alphaPriceScale

        try SubtensorStakingPallet.ensureU64Amount(minimumTaoOut)

        return minimumTaoOut
    }

    func buyFee(grossTao: Balance) throws -> SubtensorNovaFee? {
        let beneficiary = try resolveBeneficiary()

        try SubtensorStakingPallet.ensureU64Amount(grossTao)

        return makeFee(basis: grossTao, beneficiary: beneficiary)
    }

    func sellFee(alpha: Balance, limitPrice: Balance) throws -> SubtensorNovaFee? {
        let beneficiary = try resolveBeneficiary()

        let basis = try Self.minimumTaoOut(alpha: alpha, limitPrice: limitPrice)

        return makeFee(basis: basis, beneficiary: beneficiary)
    }

    func novaFee(for operation: SubtensorStakingOperation) throws -> SubtensorNovaFee? {
        switch operation {
        case .rootStake, .rootUnstake, .rootUnstakeAll, .claimRoot:
            return nil
        case let .subnetBuy(_, _, grossTao, _):
            return try buyFee(grossTao: grossTao)
        case let .subnetSell(_, _, alpha, limitPrice), let .subnetSellAll(_, _, alpha, limitPrice):
            return try sellFee(alpha: alpha, limitPrice: limitPrice)
        }
    }
}

private extension SubtensorNovaFeeCalculator {
    func resolveBeneficiary() throws -> AccountId {
        guard let beneficiary else {
            throw SubtensorStakingOperationError.novaFeeUnavailable
        }

        return beneficiary
    }

    func makeFee(basis: Balance, beneficiary: AccountId) -> SubtensorNovaFee? {
        let amount = SubtensorNovaFeeConstants.rate.mul(value: basis)

        guard amount > 0 else {
            return nil
        }

        return SubtensorNovaFee(amount: amount, beneficiary: beneficiary)
    }
}
