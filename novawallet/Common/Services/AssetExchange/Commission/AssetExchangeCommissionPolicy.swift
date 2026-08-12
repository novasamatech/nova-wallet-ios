import Foundation
import Operation_iOS
import BigInt

protocol AssetExchangeCommissionPolicyProtocol {
    func chargingOperationIndex(in path: AssetExchangeGraphPath) -> Int?

    func grossingUpAmountOut(_ netAmountOut: Balance, for path: AssetExchangeGraphPath) -> Balance

    func netAmount(from grossAmount: Balance, willCharge: Bool) -> Balance

    /// Synchronous and total, so display and charge are decided by the same call and cannot disagree.
    func resolveCommission(for route: AssetExchangeRoute) -> AssetExchangeCommission?

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

    /// Only used for synchronous, in-memory chain config lookups — never for network access, so that
    /// commission resolution stays total and cannot differ between quote time and submission time.
    let chainRegistry: ChainRegistryProtocol

    init(rate: BigRational, beneficiary: AccountId, chainRegistry: ChainRegistryProtocol) {
        self.rate = rate
        self.beneficiary = beneficiary
        self.chainRegistry = chainRegistry
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

    /// Existential deposit of the charged asset, read from the local chain config. Returns nil when the
    /// asset carries no ORML extras (native assets keep it in runtime constants, which we cannot read
    /// synchronously) — the caller then charges, matching the previous behaviour.
    func localExistentialDeposit(for chainAssetId: ChainAssetId) -> Balance? {
        guard
            let chain = try? chainRegistry.getChainOrError(for: chainAssetId.chainId),
            let asset = chain.asset(for: chainAssetId.assetId),
            let extras = try? asset.typeExtras?.map(to: OrmlTokenExtras.self) else {
            return nil
        }

        return BigUInt(extras.existentialDeposit)
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

    /// Deliberately synchronous and total: the decision depends only on the route and the local chain
    /// config, so the amount shown at quote time and the amount charged at submission cannot disagree.
    /// Nova controls the beneficiary account, so its balance is never probed.
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

        let chargedAssetId = route.items[run.lastEdgeIndex].edge.destination

        // The commission transfer rides in the same atomic batch as the swap, and orml-tokens rejects a
        // deposit that would leave a non-existent recipient account below the existential deposit. Charging
        // less than one ED would therefore revert the user's whole swap, so we forgo the commission instead.
        if let existentialDeposit = localExistentialDeposit(for: chargedAssetId),
           estimatedAmount < existentialDeposit {
            return nil
        }

        return AssetExchangeCommission(
            chargingOperationIndex: run.operationIndex,
            asset: chargedAssetId,
            estimatedAmount: estimatedAmount,
            beneficiary: beneficiary,
            rateOfGross: rateOfGross
        )
    }
}

final class AssetExchangeNoCommissionPolicy: AssetExchangeCommissionPolicyProtocol {
    func resolveCommission(for _: AssetExchangeRoute) -> AssetExchangeCommission? {
        nil
    }

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
        chainRegistry: ChainRegistryProtocol,
        logger: LoggerProtocol
    ) -> AssetExchangeCommissionPolicyProtocol {
        do {
            let beneficiary = try AssetExchangeCommissionConstants
                .hydrationBeneficiaryAddress
                .toAccountId()

            return AssetExchangeCommissionPolicy(
                rate: AssetExchangeCommissionConstants.rate,
                beneficiary: beneficiary,
                chainRegistry: chainRegistry
            )
        } catch {
            logger.error("Invalid commission beneficiary address: \(error)")

            return AssetExchangeNoCommissionPolicy()
        }
    }
}
