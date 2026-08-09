import Foundation
import Operation_iOS
import BigInt

protocol AssetExchangeCommissionPolicyProtocol {
    func chargingOperationIndex(in path: AssetExchangeGraphPath) -> Int?

    func grossingUpAmountOut(_ netAmountOut: Balance, for path: AssetExchangeGraphPath) -> Balance

    func netAmount(from grossAmount: Balance, willCharge: Bool) -> Balance

    func resolveCommissionWrapper(
        for route: AssetExchangeRoute,
        slippage: BigRational
    ) -> CompoundOperationWrapper<AssetExchangeCommission?>
}

final class AssetExchangeCommissionPolicy {
    struct ChargingRun {
        let operationIndex: Int
        let lastEdgeIndex: Int
    }

    let rate: BigRational
    let beneficiary: AccountId
    let assetStorageInfoFactory: AssetStorageInfoOperationFactoryProtocol
    let balanceQueryFactory: WalletRemoteQueryWrapperFactoryProtocol
    let chainRegistry: ChainRegistryProtocol
    let operationQueue: OperationQueue

    init(
        rate: BigRational,
        beneficiary: AccountId,
        assetStorageInfoFactory: AssetStorageInfoOperationFactoryProtocol,
        balanceQueryFactory: WalletRemoteQueryWrapperFactoryProtocol,
        chainRegistry: ChainRegistryProtocol,
        operationQueue: OperationQueue
    ) {
        self.rate = rate
        self.beneficiary = beneficiary
        self.assetStorageInfoFactory = assetStorageInfoFactory
        self.balanceQueryFactory = balanceQueryFactory
        self.chainRegistry = chainRegistry
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

    func feeTimeOutputBound(
        for route: AssetExchangeRoute,
        run: ChargingRun,
        slippage: BigRational
    ) -> Balance {
        let amountOut = route.items[run.lastEdgeIndex].amountOut(for: route.direction)

        switch route.direction {
        case .sell:
            return amountOut - slippage.mul(value: amountOut)
        case .buy:
            return amountOut
        }
    }

    func createGateWrapper(
        for chainAsset: ChainAsset,
        runtimeProvider: RuntimeCodingServiceProtocol
    ) -> CompoundOperationWrapper<Bool> {
        let storageInfoWrapper = assetStorageInfoFactory.createStorageInfoWrapper(
            from: chainAsset.asset,
            runtimeProvider: runtimeProvider
        )

        let depositWrapper = OperationCombiningService<AssetBalanceExistence>.compoundNonOptionalWrapper(
            operationQueue: operationQueue
        ) {
            let storageInfo = try storageInfoWrapper.targetOperation.extractNoCancellableResultData()

            return self.assetStorageInfoFactory.createAssetBalanceExistenceOperation(
                for: storageInfo,
                chainId: chainAsset.chain.chainId,
                asset: chainAsset.asset
            )
        }

        depositWrapper.addDependency(wrapper: storageInfoWrapper)

        let balanceWrapper = balanceQueryFactory.queryBalance(
            for: beneficiary,
            chainAsset: chainAsset
        )

        let mappingOperation = ClosureOperation<Bool> {
            let storageInfo = try storageInfoWrapper.targetOperation.extractNoCancellableResultData()

            switch storageInfo {
            case .erc20, .evmNative:
                return false
            case .native, .statemine, .orml, .ormlHydrationEvm, .equilibrium:
                break
            }

            let deposit = try depositWrapper.targetOperation.extractNoCancellableResultData()
            let balance = try balanceWrapper.targetOperation.extractNoCancellableResultData()

            return balance.freeInPlank >= deposit.minBalance
        }

        mappingOperation.addDependency(depositWrapper.targetOperation)
        mappingOperation.addDependency(balanceWrapper.targetOperation)

        let dependencies = storageInfoWrapper.allOperations
            + depositWrapper.allOperations
            + balanceWrapper.allOperations

        return CompoundOperationWrapper(targetOperation: mappingOperation, dependencies: dependencies)
    }
}

extension AssetExchangeCommissionPolicy: AssetExchangeCommissionPolicyProtocol {
    func chargingOperationIndex(in path: AssetExchangeGraphPath) -> Int? {
        findChargingRun(in: path)?.operationIndex
    }

    func grossingUpAmountOut(_ netAmountOut: Balance, for path: AssetExchangeGraphPath) -> Balance {
        guard chargingOperationIndex(in: path) != nil else {
            return netAmountOut
        }

        guard rate.denominator > rate.numerator else {
            return netAmountOut
        }

        let divisor = rate.denominator - rate.numerator

        return (netAmountOut * rate.denominator + divisor - 1) / divisor
    }

    func netAmount(from grossAmount: Balance, willCharge: Bool) -> Balance {
        guard willCharge else {
            return grossAmount
        }

        return grossAmount - rate.mul(value: grossAmount)
    }

    func resolveCommissionWrapper(
        for route: AssetExchangeRoute,
        slippage: BigRational
    ) -> CompoundOperationWrapper<AssetExchangeCommission?> {
        let path = route.items.map(\.edge)

        guard let run = findChargingRun(in: path) else {
            return .createWithResult(nil)
        }

        let bound = feeTimeOutputBound(for: route, run: run, slippage: slippage)
        let estimatedAmount = rate.mul(value: bound)

        guard estimatedAmount > 0 else {
            return .createWithResult(nil)
        }

        let chargedAssetId = route.items[run.lastEdgeIndex].edge.destination

        do {
            let chain = try chainRegistry.getChainOrError(for: chargedAssetId.chainId)
            let chainAsset = try chain.chainAssetOrError(for: chargedAssetId.assetId)
            let runtimeProvider = try chainRegistry.getRuntimeProviderOrError(
                for: chargedAssetId.chainId
            )

            let gateWrapper = createGateWrapper(
                for: chainAsset,
                runtimeProvider: runtimeProvider
            )

            let mappingOperation = ClosureOperation<AssetExchangeCommission?> {
                let canCharge = try gateWrapper.targetOperation.extractNoCancellableResultData()

                guard canCharge else {
                    return nil
                }

                return AssetExchangeCommission(
                    chargingOperationIndex: run.operationIndex,
                    asset: chargedAssetId,
                    estimatedAmount: estimatedAmount,
                    beneficiary: self.beneficiary,
                    rate: self.rate
                )
            }

            mappingOperation.addDependency(gateWrapper.targetOperation)

            return gateWrapper.insertingTail(operation: mappingOperation)
        } catch {
            return .createWithError(error)
        }
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
        for _: AssetExchangeRoute,
        slippage _: BigRational
    ) -> CompoundOperationWrapper<AssetExchangeCommission?> {
        .createWithResult(nil)
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

            return AssetExchangeCommissionPolicy(
                rate: AssetExchangeCommissionConstants.rate,
                beneficiary: beneficiary,
                assetStorageInfoFactory: AssetStorageInfoOperationFactory(
                    chainRegistry: chainRegistry,
                    operationQueue: operationQueue
                ),
                balanceQueryFactory: WalletRemoteQueryWrapperFactory(
                    chainRegistry: chainRegistry,
                    operationQueue: operationQueue
                ),
                chainRegistry: chainRegistry,
                operationQueue: operationQueue
            )
        } catch {
            logger.error("Invalid commission beneficiary address: \(error)")

            return AssetExchangeNoCommissionPolicy()
        }
    }
}
