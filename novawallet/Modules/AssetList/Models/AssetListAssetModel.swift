import Foundation
import BigInt
import RobinHood

struct AssetListAssetModel: Identifiable {
    var identifier: String { String(assetModel.assetId) }

    let assetModel: AssetModel
    let balanceResult: Result<BigUInt, Error>?
    let balanceValue: Decimal?

    let externalBalancesResult: Result<BigUInt, Error>?
    let externalBalancesValue: Decimal?

    let totalAmountDecimal: Decimal?
    let totalAmount: BigUInt?

    init(
        assetModel: AssetModel,
        balanceResult: Result<BigUInt, Error>?,
        balanceValue: Decimal?,
        externalBalancesResult: Result<BigUInt, Error>?,
        externalBalancesValue: Decimal?
    ) {
        self.assetModel = assetModel
        self.balanceResult = balanceResult
        self.balanceValue = balanceValue
        self.externalBalancesResult = externalBalancesResult
        self.externalBalancesValue = externalBalancesValue

        let maybeBalanceAmount = try? balanceResult?.get()
        let maybeExternalBalances = try? externalBalancesResult?.get()
        if let balanceAmount = maybeBalanceAmount, let externalBalancesAmount = maybeExternalBalances {
            totalAmount = balanceAmount + externalBalancesAmount
        } else {
            totalAmount = maybeBalanceAmount ?? maybeExternalBalances
        }

        totalAmountDecimal = totalAmount?.decimal(precision: assetModel.precision)
    }

    var totalValue: Decimal? {
        if let balanceValue = balanceValue, let externalBalancesValue = externalBalancesValue {
            return balanceValue + externalBalancesValue
        } else {
            return balanceValue ?? externalBalancesValue
        }
    }
}
