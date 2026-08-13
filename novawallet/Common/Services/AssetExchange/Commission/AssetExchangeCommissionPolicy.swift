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
    let beneficiaryProvider: AssetExchangeCommissionBeneficiaryProviding
    let logger: LoggerProtocol

    init(
        rate: BigRational,
        beneficiary: AccountId,
        beneficiaryProvider: AssetExchangeCommissionBeneficiaryProviding,
        logger: LoggerProtocol
    ) {
        self.rate = rate
        self.beneficiary = beneficiary
        self.beneficiaryProvider = beneficiaryProvider
        self.logger = logger
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

    func canReceiveWrapper(for chainId: ChainModel.Id) -> CompoundOperationWrapper<Bool> {
        let stateWrapper = beneficiaryProvider.fetchStateWrapper(for: chainId)

        let mappingOperation = ClosureOperation<Bool> {
            do {
                return try stateWrapper.targetOperation.extractNoCancellableResultData().canReceive
            } catch {
                self.logger.error("Beneficiary readiness failed for \(chainId): \(error)")

                return false
            }
        }

        mappingOperation.addDependency(stateWrapper.targetOperation)

        return stateWrapper.insertingTail(operation: mappingOperation)
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
        guard let run = findChargingRun(in: path) else {
            return .createWithResult(netAmountOut)
        }

        let canReceiveWrapper = canReceiveWrapper(for: path[run.lastEdgeIndex].destination.chainId)

        let mappingOperation = ClosureOperation<Balance> {
            let canReceive = try canReceiveWrapper.targetOperation.extractNoCancellableResultData()

            guard canReceive else {
                return netAmountOut
            }

            return netAmountOut + self.rate.mul(value: netAmountOut)
        }

        mappingOperation.addDependency(canReceiveWrapper.targetOperation)

        return canReceiveWrapper.insertingTail(operation: mappingOperation)
    }

    func resolveCommissionWrapper(
        for route: AssetExchangeRoute
    ) -> CompoundOperationWrapper<AssetExchangeCommission?> {
        let path = route.items.map(\.edge)

        guard let run = findChargingRun(in: path) else {
            return .createWithResult(nil)
        }

        let bound = route.items[run.lastEdgeIndex].amountOut(for: route.direction)
        let estimatedAmount = rateOfGross.mul(value: bound)
        let chargedAssetId = route.items[run.lastEdgeIndex].edge.destination

        guard estimatedAmount > 0 else {
            return .createWithResult(nil)
        }

        let canReceiveWrapper = canReceiveWrapper(for: chargedAssetId.chainId)

        let mappingOperation = ClosureOperation<AssetExchangeCommission?> {
            let canReceive = try canReceiveWrapper.targetOperation.extractNoCancellableResultData()

            guard canReceive else {
                return nil
            }

            return AssetExchangeCommission(
                chargingOperationIndex: run.operationIndex,
                asset: chargedAssetId,
                estimatedAmount: estimatedAmount,
                beneficiary: self.beneficiary,
                rateOfGross: self.rateOfGross
            )
        }

        mappingOperation.addDependency(canReceiveWrapper.targetOperation)

        return canReceiveWrapper.insertingTail(operation: mappingOperation)
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
    static func createHydrationPolicy(
        chainRegistry: ChainRegistryProtocol,
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) -> AssetExchangeCommissionPolicyProtocol {
        do {
            let beneficiary = try AssetExchangeCommissionConstants
                .hydrationBeneficiaryAddress
                .toAccountId()

            let provider = AssetExchangeCommissionBeneficiaryProvider(
                beneficiary: beneficiary,
                balanceQueryFactory: WalletRemoteQueryWrapperFactory(
                    chainRegistry: chainRegistry,
                    operationQueue: operationQueue
                ),
                assetStorageInfoFactory: AssetStorageInfoOperationFactory(
                    chainRegistry: chainRegistry,
                    operationQueue: operationQueue
                ),
                chainRegistry: chainRegistry,
                operationQueue: operationQueue
            )

            return AssetExchangeCommissionPolicy(
                rate: AssetExchangeCommissionConstants.rate,
                beneficiary: beneficiary,
                beneficiaryProvider: provider,
                logger: logger
            )
        } catch {
            logger.error("Invalid commission beneficiary address: \(error)")

            return AssetExchangeNoCommissionPolicy()
        }
    }
}
