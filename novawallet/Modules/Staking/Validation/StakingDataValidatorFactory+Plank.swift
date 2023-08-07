import Foundation
import BigInt

extension StakingDataValidatingFactoryProtocol {
    func canNominateInPlank(
        amount: Decimal?,
        minimalBalance: BigUInt?,
        minNominatorBond: BigUInt?,
        precision: UInt16,
        locale: Locale
    ) -> DataValidating {
        let minimalBalanceDecimal = minimalBalance?.decimal(precision: precision)
        let minNominatorBondDecimal = minNominatorBond?.decimal(precision: precision)

        return canNominate(
            amount: amount,
            minimalBalance: minimalBalanceDecimal,
            minNominatorBond: minNominatorBondDecimal,
            locale: locale
        )
    }
}
