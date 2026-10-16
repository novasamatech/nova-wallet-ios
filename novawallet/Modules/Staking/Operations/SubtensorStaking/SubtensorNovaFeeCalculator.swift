import BigInt
import Foundation

struct SubtensorNovaFeeCalculator {
    var beneficiary: AccountId? = SubtensorNovaFeeCalculator.defaultBeneficiary
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

        let gross = net + SubtensorNovaFeeRateStore.shared.rate.mul(value: net - 1)

        try SubtensorStakingPallet.ensureU64Amount(gross)

        return gross
    }

    func fee(basis: Balance) throws -> SubtensorNovaFee? {
        guard let beneficiary else {
            throw SubtensorStakingOperationError.novaFeeUnavailable
        }

        try SubtensorStakingPallet.ensureU64Amount(basis)

        let amount = SubtensorNovaFeeRateStore.shared.rate.asShareOfGross.mul(value: basis)

        guard amount > 0 else {
            return nil
        }

        return SubtensorNovaFee(amount: amount, beneficiary: beneficiary)
    }

    func novaFee(for operation: SubtensorStakingOperation) throws -> SubtensorNovaFee? {
        switch operation {
        case .rootStake, .rootUnstake, .rootUnstakeAll, .rootClaim:
            return nil
        case let .subnetBuy(_, _, grossTao, _):
            return try fee(basis: grossTao)
        case let .subnetSell(_, _, _, _, quotedTaoOut), let .subnetSellAll(_, _, _, quotedTaoOut):
            return try fee(basis: quotedTaoOut)
        }
    }
}
