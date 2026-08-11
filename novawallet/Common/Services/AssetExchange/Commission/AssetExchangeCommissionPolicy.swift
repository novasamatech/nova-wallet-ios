import Foundation
import Operation_iOS
import BigInt

protocol AssetExchangeCommissionPolicyProtocol {
    func chargingOperationIndex(in path: AssetExchangeGraphPath) -> Int?

    func grossingUpAmountOut(_ netAmountOut: Balance, for path: AssetExchangeGraphPath) -> Balance

    func netAmount(from grossAmount: Balance, willCharge: Bool) -> Balance

    func resolveCommissionWrapper(
        for route: AssetExchangeRoute
    ) -> CompoundOperationWrapper<AssetExchangeCommission?>
}

final class AssetExchangeCommissionPolicy {
    struct ChargingRun {
        let operationIndex: Int
        let lastEdgeIndex: Int
    }

    /// Share of the amount the user receives — the advertised 0.85%.
    let rate: BigRational

    /// The same commission as a share of the pool output, which is what every deduction is applied to.
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

    func feeTimeOutputBound(for route: AssetExchangeRoute, run: ChargingRun) -> Balance {
        route.items[run.lastEdgeIndex].amountOut(for: route.direction)
    }
}

extension AssetExchangeCommissionPolicy: AssetExchangeCommissionPolicyProtocol {
    func chargingOperationIndex(in path: AssetExchangeGraphPath) -> Int? {
        findChargingRun(in: path)?.operationIndex
    }

    /// Adds the commission on top of the amount the user asked to receive, so that after the deduction
    /// they are left with exactly what they entered.
    func grossingUpAmountOut(_ netAmountOut: Balance, for path: AssetExchangeGraphPath) -> Balance {
        guard chargingOperationIndex(in: path) != nil else {
            return netAmountOut
        }

        return netAmountOut + rate.mul(value: netAmountOut)
    }

    func netAmount(from grossAmount: Balance, willCharge: Bool) -> Balance {
        guard willCharge else {
            return grossAmount
        }

        return grossAmount - rateOfGross.mul(value: grossAmount)
    }

    func resolveCommissionWrapper(
        for route: AssetExchangeRoute
    ) -> CompoundOperationWrapper<AssetExchangeCommission?> {
        .createWithResult(resolveCommission(for: route))
    }

    /// Deliberately synchronous and total: the decision depends only on the route, so the amount shown at
    /// quote time and the amount charged at submission can never disagree. Nova controls the beneficiary
    /// account, so there is no need to probe its balance before charging.
    func resolveCommission(for route: AssetExchangeRoute) -> AssetExchangeCommission? {
        let path = route.items.map(\.edge)

        guard let run = findChargingRun(in: path) else {
            return nil
        }

        let bound = feeTimeOutputBound(for: route, run: run)
        let estimatedAmount = rateOfGross.mul(value: bound)

        guard estimatedAmount > 0 else {
            return nil
        }

        return AssetExchangeCommission(
            chargingOperationIndex: run.operationIndex,
            asset: route.items[run.lastEdgeIndex].edge.destination,
            estimatedAmount: estimatedAmount,
            beneficiary: beneficiary,
            rateOfGross: rateOfGross
        )
    }
}

final class AssetExchangeNoCommissionPolicy: AssetExchangeCommissionPolicyProtocol {
    func chargingOperationIndex(in _: AssetExchangeGraphPath) -> Int? {
        nil
    }

    func grossingUpAmountOut(_ netAmountOut: Balance, for _: AssetExchangeGraphPath) -> Balance {
        netAmountOut
    }

    func netAmount(from grossAmount: Balance, willCharge _: Bool) -> Balance {
        grossAmount
    }

    func resolveCommissionWrapper(
        for _: AssetExchangeRoute
    ) -> CompoundOperationWrapper<AssetExchangeCommission?> {
        .createWithResult(nil)
    }
}

enum AssetExchangeCommissionPolicyFactory {
    static func createHydrationPolicy(
        logger: LoggerProtocol
    ) -> AssetExchangeCommissionPolicyProtocol {
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
