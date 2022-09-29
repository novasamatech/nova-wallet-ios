import Foundation
import BigInt
import RobinHood

struct AssetListAssetModel: Identifiable {
    var identifier: String { String(assetModel.assetId) }

    let assetModel: AssetModel
    let balanceResult: Result<BigUInt, Error>?
    let balanceValue: Decimal?

    let crowdloanResult: Result<BigUInt, Error>?
    let crowdloanValue: Decimal?

    var totalAmount: BigUInt? {
        let maybeBalanceAmount = try? balanceResult?.get()
        let maybeCrowdloanContribution = try? crowdloanResult?.get()
        if let balanceAmount = maybeBalanceAmount, let crowdloanAmount = maybeCrowdloanContribution {
            return balanceAmount + crowdloanAmount
        } else {
            return maybeBalanceAmount ?? maybeCrowdloanContribution
        }
    }

    var totalValue: Decimal? {
        if let balanceValue = balanceValue, let crowdloanValue = crowdloanValue {
            return balanceValue + crowdloanValue
        } else {
            return balanceValue ?? crowdloanValue
        }
    }
}
