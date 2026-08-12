import Foundation
import Operation_iOS
import BigInt

protocol AssetExchangeCommissionPolicyProtocol {
    func chargingOperationIndex(in path: AssetExchangeGraphPath) -> Int?

    func grossingUpAmountOut(_ netAmountOut: Balance, for path: AssetExchangeGraphPath) -> Balance

    func netAmount(from grossAmount: Balance, willCharge: Bool) -> Balance

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

    let rate: BigRational

    var rateOfGross: BigRational { rate.asShareOfGross }

    let beneficiary: AccountId

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

    func willCharge(grossAmount: Balance, chargedAssetId: ChainAssetId) -> Bool {
        let estimatedAmount = rateOfGross.mul(value: grossAmount)

        guard estimatedAmount > 0 else {
            return false
        }

        if let existentialDeposit = localExistentialDeposit(for: chargedAssetId),
           estimatedAmount < existentialDeposit {
            return false
        }

        return true
    }

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

    func grossingUpAmountOut(_ netAmountOut: Balance, for path: AssetExchangeGraphPath) -> Balance {
        guard let run = findChargingRun(in: path) else {
            return netAmountOut
        }

        let grossAmountOut = netAmountOut + rate.mul(value: netAmountOut)

        guard willCharge(
            grossAmount: grossAmountOut,
            chargedAssetId: path[run.lastEdgeIndex].destination
        ) else {
            return netAmountOut
        }

        return grossAmountOut
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

    func resolveCommission(for route: AssetExchangeRoute) -> AssetExchangeCommission? {
        let path = route.items.map(\.edge)

        guard let run = findChargingRun(in: path) else {
            return nil
        }

        let bound = feeTimeOutputBound(for: route, run: run)
        let estimatedAmount = rateOfGross.mul(value: bound)
        let chargedAssetId = route.items[run.lastEdgeIndex].edge.destination

        guard willCharge(grossAmount: bound, chargedAssetId: chargedAssetId) else {
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
