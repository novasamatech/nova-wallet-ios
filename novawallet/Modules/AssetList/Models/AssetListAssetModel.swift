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

    var totalAmount: BigUInt? {
        let maybeBalanceAmount = try? balanceResult?.get()
        let maybeExternalBalances = try? externalBalancesResult?.get()
        if let balanceAmount = maybeBalanceAmount, let externalBalancesAmount = maybeExternalBalances {
            return balanceAmount + externalBalancesAmount
        } else {
            return maybeBalanceAmount ?? maybeExternalBalances
        }
    }

    var totalValue: Decimal? {
        if let balanceValue = balanceValue, let externalBalancesValue = externalBalancesValue {
            return balanceValue + externalBalancesValue
        } else {
            return balanceValue ?? externalBalancesValue
        }
    }
}
