import Foundation
import BigInt
import Operation_iOS

struct AssetListAssetModel: Identifiable {
    var identifier: String { chainAssetModel.chainAssetId.stringValue }

    let chainAssetModel: ChainAsset
    let balanceResult: Result<BigUInt, Error>?
    let balanceValue: Decimal?

    let externalBalancesResult: Result<BigUInt, Error>?
    let externalBalancesValue: Decimal?

    let totalAmountDecimal: Decimal?
    let totalAmount: BigUInt?

    init(
        chainAssetModel: ChainAsset,
        balanceResult: Result<BigUInt, Error>?,
        balanceValue: Decimal?,
        externalBalancesResult: Result<BigUInt, Error>?,
        externalBalancesValue: Decimal?
    ) {
        self.chainAssetModel = chainAssetModel
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

        totalAmountDecimal = totalAmount?.decimal(precision: chainAssetModel.asset.precision)
    }

    var totalValue: Decimal? {
        if let balanceValue = balanceValue, let externalBalancesValue = externalBalancesValue {
            return balanceValue + externalBalancesValue
        } else {
            return balanceValue ?? externalBalancesValue
        }
    }
}
