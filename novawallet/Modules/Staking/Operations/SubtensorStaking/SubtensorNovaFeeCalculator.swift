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
            let accountId = try? SubtensorNovaFeeConstants.beneficiaryAddress.toAccountId(
                using: .defaultSubstrateFormat
            ),
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

    static func grossUp(net: Balance) throws -> Balance {
        try SubtensorStakingPallet.ensureU64Amount(net)

        guard net > 0 else {
            return 0
        }

        let gross = net + SubtensorNovaFeeConstants.rate.mul(value: net - 1)

        try SubtensorStakingPallet.ensureU64Amount(gross)

        return gross
    }

    func buyFee(grossTao: Balance) throws -> SubtensorNovaFee? {
        let beneficiary = try resolveBeneficiary()

        try SubtensorStakingPallet.ensureU64Amount(grossTao)

        return makeFee(basis: grossTao, beneficiary: beneficiary)
    }

    func sellFee(quotedTaoOut: Balance) throws -> SubtensorNovaFee? {
        let beneficiary = try resolveBeneficiary()

        try SubtensorStakingPallet.ensureU64Amount(quotedTaoOut)

        return makeFee(basis: quotedTaoOut, beneficiary: beneficiary)
    }

    func novaFee(for operation: SubtensorStakingOperation) throws -> SubtensorNovaFee? {
        switch operation {
        case .rootStake, .rootUnstake, .rootUnstakeAll, .rootClaim:
            return nil
        case let .subnetBuy(_, _, grossTao, _):
            return try buyFee(grossTao: grossTao)
        case let .subnetSell(_, _, _, _, quotedTaoOut), let .subnetSellAll(_, _, _, quotedTaoOut):
            return try sellFee(quotedTaoOut: quotedTaoOut)
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
        let amount = SubtensorNovaFeeConstants.rate.asShareOfGross.mul(value: basis)

        guard amount > 0 else {
            return nil
        }

        return SubtensorNovaFee(amount: amount, beneficiary: beneficiary)
    }
}
