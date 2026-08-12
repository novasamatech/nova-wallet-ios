import Foundation
import Operation_iOS
import BigInt

protocol AssetExchangeCommissionPolicyProtocol {
    func netAmount(from grossAmount: Balance, willCharge: Bool) -> Balance

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
    let chainRegistry: ChainRegistryProtocol
    let beneficiaryProvider: AssetExchangeCommissionBeneficiaryProviding
    let operationQueue: OperationQueue

    init(
        rate: BigRational,
        beneficiary: AccountId,
        chainRegistry: ChainRegistryProtocol,
        beneficiaryProvider: AssetExchangeCommissionBeneficiaryProviding,
        operationQueue: OperationQueue
    ) {
        self.rate = rate
        self.beneficiary = beneficiary
        self.chainRegistry = chainRegistry
        self.beneficiaryProvider = beneficiaryProvider
        self.operationQueue = operationQueue
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

    func chargedChainAsset(for chainAssetId: ChainAssetId) -> ChainAsset? {
        guard
            let chain = try? chainRegistry.getChainOrError(for: chainAssetId.chainId),
            let asset = chain.asset(for: chainAssetId.assetId) else {
            return nil
        }

        return ChainAsset(chain: chain, asset: asset)
    }

    func canReceiveWrapper(for chainAssetId: ChainAssetId) -> CompoundOperationWrapper<Bool> {
        guard let chainAsset = chargedChainAsset(for: chainAssetId) else {
            return .createWithResult(false)
        }

        let stateWrapper = beneficiaryProvider.fetchStateWrapper(for: chainAsset)

        let mappingOperation = ClosureOperation<Bool> {
            do {
                return try stateWrapper.targetOperation.extractNoCancellableResultData().canReceive
            } catch {
                return false
            }
        }

        mappingOperation.addDependency(stateWrapper.targetOperation)

        return stateWrapper.insertingTail(operation: mappingOperation)
    }
}

extension AssetExchangeCommissionPolicy: AssetExchangeCommissionPolicyProtocol {
    func netAmount(from grossAmount: Balance, willCharge: Bool) -> Balance {
        guard willCharge else {
            return grossAmount
        }

        return grossAmount - rateOfGross.mul(value: grossAmount)
    }

    func grossingUpAmountOutWrapper(
        _ netAmountOut: Balance,
        for path: AssetExchangeGraphPath
    ) -> CompoundOperationWrapper<Balance> {
        guard let run = findChargingRun(in: path) else {
            return .createWithResult(netAmountOut)
        }

        let canReceiveWrapper = canReceiveWrapper(for: path[run.lastEdgeIndex].destination)

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

        let canReceiveWrapper = canReceiveWrapper(for: chargedAssetId)

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
    func netAmount(from grossAmount: Balance, willCharge _: Bool) -> Balance {
        grossAmount
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
                chainRegistry: chainRegistry,
                beneficiaryProvider: provider,
                operationQueue: operationQueue
            )
        } catch {
            logger.error("Invalid commission beneficiary address: \(error)")

            return AssetExchangeNoCommissionPolicy()
        }
    }
}
