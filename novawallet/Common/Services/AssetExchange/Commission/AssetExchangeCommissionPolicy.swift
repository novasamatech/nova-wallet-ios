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
    let chainRegistry: ChainRegistryProtocol
    let assetStorageInfoFactory: AssetStorageInfoOperationFactoryProtocol
    let logger: LoggerProtocol

    init(
        rate: BigRational,
        beneficiary: AccountId,
        beneficiaryProvider: AssetExchangeCommissionBeneficiaryProviding,
        chainRegistry: ChainRegistryProtocol,
        assetStorageInfoFactory: AssetStorageInfoOperationFactoryProtocol,
        logger: LoggerProtocol
    ) {
        self.rate = rate
        self.beneficiary = beneficiary
        self.beneficiaryProvider = beneficiaryProvider
        self.chainRegistry = chainRegistry
        self.assetStorageInfoFactory = assetStorageInfoFactory
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

    static func minimumChargeableAmount(for storageInfo: AssetStorageInfo) -> Balance? {
        switch storageInfo {
        case let .orml(info), let .ormlHydrationEvm(info):
            return info.existentialDeposit > 0 ? info.existentialDeposit : nil
        case .native:
            return 0
        default:
            return nil
        }
    }

    func chargedAssetStorageInfoWrapper(
        for chargedAsset: ChainAssetId
    ) -> CompoundOperationWrapper<AssetStorageInfo> {
        do {
            let chain = try chainRegistry.getChainOrError(for: chargedAsset.chainId)
            let runtimeProvider = try chainRegistry.getRuntimeProviderOrError(for: chargedAsset.chainId)

            guard let asset = chain.asset(for: chargedAsset.assetId) else {
                throw ChainModelFetchError.noAsset(assetId: chargedAsset.assetId)
            }

            return assetStorageInfoFactory.createStorageInfoWrapper(
                from: asset,
                runtimeProvider: runtimeProvider
            )
        } catch {
            return .createWithError(error)
        }
    }

    func chargeableAmountWrapper(
        of grossAmount: Balance,
        chargedAsset: ChainAssetId
    ) -> CompoundOperationWrapper<Balance?> {
        let amount = rateOfGross.mul(value: grossAmount)

        guard amount > 0 else {
            return .createWithResult(nil)
        }

        let readinessWrapper = canReceiveWrapper(for: chargedAsset.chainId)
        let storageInfoWrapper = chargedAssetStorageInfoWrapper(for: chargedAsset)

        let mappingOperation = ClosureOperation<Balance?> {
            let canReceive = try readinessWrapper.targetOperation.extractNoCancellableResultData()

            guard canReceive else {
                return nil
            }

            let storageInfo: AssetStorageInfo

            do {
                storageInfo = try storageInfoWrapper.targetOperation.extractNoCancellableResultData()
            } catch {
                self.logger.error("Charged asset storage info failed for \(chargedAsset): \(error)")

                return nil
            }

            guard
                let minimumAmount = Self.minimumChargeableAmount(for: storageInfo),
                amount >= minimumAmount else {
                return nil
            }

            return amount
        }

        mappingOperation.addDependency(readinessWrapper.targetOperation)
        mappingOperation.addDependency(storageInfoWrapper.targetOperation)

        return CompoundOperationWrapper(
            targetOperation: mappingOperation,
            dependencies: readinessWrapper.allOperations + storageInfoWrapper.allOperations
        )
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
        let chargedAssetId = route.items[run.lastEdgeIndex].edge.destination

        let chargeableWrapper = chargeableAmountWrapper(of: bound, chargedAsset: chargedAssetId)

        let mappingOperation = ClosureOperation<AssetExchangeCommission?> {
            let chargeableAmount = try chargeableWrapper.targetOperation.extractNoCancellableResultData()

            guard let chargeableAmount else {
                return nil
            }

            return AssetExchangeCommission(
                chargingOperationIndex: run.operationIndex,
                asset: chargedAssetId,
                amount: chargeableAmount,
                beneficiary: self.beneficiary
            )
        }

        mappingOperation.addDependency(chargeableWrapper.targetOperation)

        return chargeableWrapper.insertingTail(operation: mappingOperation)
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

            let assetStorageInfoFactory = AssetStorageInfoOperationFactory(
                chainRegistry: chainRegistry,
                operationQueue: operationQueue
            )

            let provider = AssetExchangeCommissionBeneficiaryProvider(
                beneficiary: beneficiary,
                balanceQueryFactory: WalletRemoteQueryWrapperFactory(
                    chainRegistry: chainRegistry,
                    operationQueue: operationQueue
                ),
                assetStorageInfoFactory: assetStorageInfoFactory,
                chainRegistry: chainRegistry,
                operationQueue: operationQueue
            )

            return AssetExchangeCommissionPolicy(
                rate: AssetExchangeCommissionConstants.rate,
                beneficiary: beneficiary,
                beneficiaryProvider: provider,
                chainRegistry: chainRegistry,
                assetStorageInfoFactory: assetStorageInfoFactory,
                logger: logger
            )
        } catch {
            logger.error("Invalid commission beneficiary address: \(error)")

            return AssetExchangeNoCommissionPolicy()
        }
    }
}
