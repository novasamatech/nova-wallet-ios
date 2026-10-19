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
        try SubtensorPallet.ensureU64Amount(alpha)
        try SubtensorPallet.ensureU64Amount(limitPrice)

        let minimumTaoOut = alpha * limitPrice / SubtensorPallet.alphaPriceScale

        try SubtensorPallet.ensureU64Amount(minimumTaoOut)

        return minimumTaoOut
    }

    static func grossUp(net: Balance, rate: BigRational) throws -> Balance {
        try SubtensorPallet.ensureU64Amount(net)

        guard net > 0 else {
            return 0
        }

        let gross = net + rate.mul(value: net - 1)

        try SubtensorPallet.ensureU64Amount(gross)

        return gross
    }

    func fee(basis: Balance, rate: BigRational) throws -> SubtensorNovaFee? {
        guard let beneficiary else {
            throw SubtensorOperationError.novaFeeUnavailable
        }

        try SubtensorPallet.ensureU64Amount(basis)

        let amount = rate.asShareOfGross.mul(value: basis)

        guard amount > 0 else {
            return nil
        }

        return SubtensorNovaFee(amount: amount, beneficiary: beneficiary)
    }
}
