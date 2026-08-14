import Foundation
import BigInt

protocol AssetExchangeCommissionPolicyProtocol {
    func hasChargingSite(in path: AssetExchangeGraphPath) -> Bool

    func resolveCommission(for route: AssetExchangeRoute) -> AssetExchangeCommission?

    func grossingUpAmountOut(_ netAmountOut: Balance, for path: AssetExchangeGraphPath) -> Balance
}

final class AssetExchangeCommissionPolicy {
    struct ChargingRun {
        let operationIndex: Int
        let lastEdgeIndex: Int
    }

    let rate: BigRational

    var rateOfGross: BigRational { rate.asShareOfGross }

    let beneficiary: AccountId

    init(rate: BigRational, beneficiary: AccountId) {
        self.rate = rate
        self.beneficiary = beneficiary
    }
}

private extension AssetExchangeCommissionPolicy {
    func findChargingRun(in path: AssetExchangeGraphPath) -> ChargingRun? {
        var ordinal = -1
        var result: ChargingRun?

        for (edgeIndex, edge) in path.enumerated() {
            let continuesRun = edgeIndex > 0
                && edge.type == .hydraSwap
                && path[edgeIndex - 1].type == .hydraSwap

            if !continuesRun {
                ordinal += 1
            }

            guard edge.type == .hydraSwap else {
                continue
            }

            result = ChargingRun(operationIndex: ordinal, lastEdgeIndex: edgeIndex)
        }

        return result
    }
}

extension AssetExchangeCommissionPolicy: AssetExchangeCommissionPolicyProtocol {
    func hasChargingSite(in path: AssetExchangeGraphPath) -> Bool {
        findChargingRun(in: path) != nil
    }

    func grossingUpAmountOut(_ netAmountOut: Balance, for path: AssetExchangeGraphPath) -> Balance {
        guard findChargingRun(in: path) != nil else {
            return netAmountOut
        }

        return netAmountOut + rate.mul(value: netAmountOut)
    }

    func resolveCommission(for route: AssetExchangeRoute) -> AssetExchangeCommission? {
        let path = route.items.map(\.edge)

        guard let run = findChargingRun(in: path) else {
            return nil
        }

        let bound = route.items[run.lastEdgeIndex].amountOut(for: route.direction)
        let amount = rateOfGross.mul(value: bound)

        guard amount > 0 else {
            return nil
        }

        return AssetExchangeCommission(
            chargingOperationIndex: run.operationIndex,
            asset: route.items[run.lastEdgeIndex].edge.destination,
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
