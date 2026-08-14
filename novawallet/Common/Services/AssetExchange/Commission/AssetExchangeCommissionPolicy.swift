import Foundation
import Operation_iOS
import BigInt

protocol AssetExchangeCommissionPolicyProtocol {
    func hasChargingSite(in path: AssetExchangeGraphPath) -> Bool

    func resolveCommissionWrapper(
        for route: AssetExchangeRoute
    ) -> CompoundOperationWrapper<AssetExchangeCommission?>

    func grossingUpAmountOutWrapper(
        _ netAmountOut: Balance,
        for path: AssetExchangeGraphPath
    ) -> CompoundOperationWrapper<Balance>
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

    func grossingUpAmountOutWrapper(
        _ netAmountOut: Balance,
        for path: AssetExchangeGraphPath
    ) -> CompoundOperationWrapper<Balance> {
        guard findChargingRun(in: path) != nil else {
            return .createWithResult(netAmountOut)
        }

        return .createWithResult(netAmountOut + rate.mul(value: netAmountOut))
    }

    func resolveCommissionWrapper(
        for route: AssetExchangeRoute
    ) -> CompoundOperationWrapper<AssetExchangeCommission?> {
        let path = route.items.map(\.edge)

        guard let run = findChargingRun(in: path) else {
            return .createWithResult(nil)
        }

        let bound = route.items[run.lastEdgeIndex].amountOut(for: route.direction)
        let amount = rateOfGross.mul(value: bound)

        guard amount > 0 else {
            return .createWithResult(nil)
        }

        return .createWithResult(
            AssetExchangeCommission(
                chargingOperationIndex: run.operationIndex,
                asset: route.items[run.lastEdgeIndex].edge.destination,
                amount: amount,
                beneficiary: beneficiary
            )
        )
    }
}

final class AssetExchangeNoCommissionPolicy: AssetExchangeCommissionPolicyProtocol {
    func hasChargingSite(in _: AssetExchangeGraphPath) -> Bool {
        false
    }

    func resolveCommissionWrapper(
        for _: AssetExchangeRoute
    ) -> CompoundOperationWrapper<AssetExchangeCommission?> {
        .createWithResult(nil)
    }

    func grossingUpAmountOutWrapper(
        _ netAmountOut: Balance,
        for _: AssetExchangeGraphPath
    ) -> CompoundOperationWrapper<Balance> {
        .createWithResult(netAmountOut)
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
