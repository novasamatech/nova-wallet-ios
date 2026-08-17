import Foundation
import BigInt

protocol AssetExchangeCommissionPolicyProtocol {
    func hasChargingSite(in path: AssetExchangeGraphPath) -> Bool

    func resolveCommission(for route: AssetExchangeRoute) -> AssetExchangeCommission?

    func grossingUpAmountOut(_ netAmountOut: Balance, for path: AssetExchangeGraphPath) -> Balance
}

final class AssetExchangeCommissionPolicy {
    let rate: BigRational

    var rateOfGross: BigRational { rate.asShareOfGross }

    let beneficiary: AccountId

    init(rate: BigRational, beneficiary: AccountId) {
        self.rate = rate
        self.beneficiary = beneficiary
    }
}

private extension AssetExchangeCommissionPolicy {
    func findChargingEdgeIndex(in path: AssetExchangeGraphPath) -> Int? {
        path.lastIndex { $0.type == .hydraSwap }
    }
}

extension AssetExchangeCommissionPolicy: AssetExchangeCommissionPolicyProtocol {
    func hasChargingSite(in path: AssetExchangeGraphPath) -> Bool {
        findChargingEdgeIndex(in: path) != nil
    }

    func grossingUpAmountOut(_ netAmountOut: Balance, for path: AssetExchangeGraphPath) -> Balance {
        guard findChargingEdgeIndex(in: path) != nil else {
            return netAmountOut
        }

        return netAmountOut + rate.mul(value: netAmountOut)
    }

    func resolveCommission(for route: AssetExchangeRoute) -> AssetExchangeCommission? {
        let path = route.items.map(\.edge)

        guard let edgeIndex = findChargingEdgeIndex(in: path) else {
            return nil
        }

        let bound = route.items[edgeIndex].amountOut(for: route.direction)
        let amount = rateOfGross.mul(value: bound)

        guard amount > 0 else {
            return nil
        }

        return AssetExchangeCommission(
            chargingEdgeIndex: edgeIndex,
            asset: route.items[edgeIndex].edge.destination,
            amount: amount,
            beneficiary: beneficiary
        )
    }
}

final class AssetExchangeNoCommissionPolicy: AssetExchangeCommissionPolicyProtocol {
    func hasChargingSite(in _: AssetExchangeGraphPath) -> Bool {
        false
    }

    func resolveCommission(for _: AssetExchangeRoute) -> AssetExchangeCommission? {
        nil
    }

    func grossingUpAmountOut(_ netAmountOut: Balance, for _: AssetExchangeGraphPath) -> Balance {
        netAmountOut
    }
}

enum AssetExchangeCommissionPolicyFactory {
    static func createHydrationPolicy(logger: LoggerProtocol) -> AssetExchangeCommissionPolicyProtocol {
        do {
            let beneficiary = try AssetExchangeCommissionConstants
                .hydrationBeneficiaryAddress
                .toAccountId()

            return AssetExchangeCommissionPolicy(
                rate: AssetExchangeCommissionConstants.rate,
                beneficiary: beneficiary
            )
        } catch {
            logger.error("Invalid commission beneficiary address: \(error)")

            return AssetExchangeNoCommissionPolicy()
        }
    }
}
