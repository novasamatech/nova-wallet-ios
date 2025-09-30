import Foundation
import SubstrateSdk
import Operation_iOS

struct StakingUnclaimedReward {
    let accountId: AccountId
    let era: Staking.EraIndex
    let pages: Set<Staking.ValidatorPage>
}

protocol StakingUnclaimedRewardsFacadeProtocol {
    func createWrapper(
        for validatorsClosure: @escaping () throws -> [StakingValidatorExposure],
        exposurePagedEra: @escaping () throws -> Staking.EraIndex?,
        codingFactoryClosure: @escaping () throws -> RuntimeCoderFactoryProtocol,
        connection: JSONRPCEngine
    ) -> CompoundOperationWrapper<[StakingUnclaimedReward]>
}

protocol StakingUnclaimedRewardsOperationFactoryProtocol {
    func createWrapper(
        for validatorsClosure: @escaping () throws -> [StakingValidatorExposure],
        codingFactoryClosure: @escaping () throws -> RuntimeCoderFactoryProtocol,
        connection: JSONRPCEngine
    ) -> CompoundOperationWrapper<[StakingUnclaimedReward]>
}

final class StakingUnclaimedRewardsFacade {
    let requestFactory: StorageRequestFactoryProtocol
    let operationQueue: OperationQueue

    init(requestFactory: StorageRequestFactoryProtocol, operationQueue: OperationQueue) {
        self.requestFactory = requestFactory
        self.operationQueue = operationQueue
    }

    func createLedgerBasedWrapper(
        for validators: [StakingValidatorExposure],
        codingFactoryClosure: @escaping () throws -> RuntimeCoderFactoryProtocol,
        connection: JSONRPCEngine
    ) -> CompoundOperationWrapper<[StakingUnclaimedReward]> {
        StakingLedgerUnclaimedRewardsFactory(
            requestFactory: requestFactory
        ).createWrapper(
            for: { validators },
            codingFactoryClosure: codingFactoryClosure,
            connection: connection
        )
    }

    func createClaimedBasedWrapper(
        for validators: [StakingValidatorExposure],
        codingFactoryClosure: @escaping () throws -> RuntimeCoderFactoryProtocol,
        connection: JSONRPCEngine
    ) -> CompoundOperationWrapper<[StakingUnclaimedReward]> {
        let legacyWrapper = createLedgerBasedWrapper(
            for: validators,
            codingFactoryClosure: codingFactoryClosure,
            connection: connection
        )

        let claimedRewardsWrapper = StakingClaimedRewardsOperationFactory(
            requestFactory: requestFactory
        ).createWrapper(
            for: { validators },
            codingFactoryClosure: codingFactoryClosure,
            connection: connection
        )

        let mergeOperation = ClosureOperation<[StakingUnclaimedReward]> {
            let legacyResults = try legacyWrapper.targetOperation.extractNoCancellableResultData()
            let pagedResults = try claimedRewardsWrapper.targetOperation.extractNoCancellableResultData()

            let legacyUnclaimed: Set<ResolvedValidatorEra> = Set(
                legacyResults.map { ResolvedValidatorEra(validator: $0.accountId, era: $0.era) }
            )

            return pagedResults.filter { unclaimedReward in
                let validatorEra = ResolvedValidatorEra(
                    validator: unclaimedReward.accountId,
                    era: unclaimedReward.era
                )

                return legacyUnclaimed.contains(validatorEra)
            }
        }

        mergeOperation.addDependency(claimedRewardsWrapper.targetOperation)
        mergeOperation.addDependency(legacyWrapper.targetOperation)

        return claimedRewardsWrapper
            .insertingHead(operations: legacyWrapper.allOperations)
            .insertingTail(operation: mergeOperation)
    }
}

extension StakingUnclaimedRewardsFacade: StakingUnclaimedRewardsFacadeProtocol {
    func createWrapper(
        for validatorsClosure: @escaping () throws -> [StakingValidatorExposure],
        exposurePagedEra: @escaping () throws -> Staking.EraIndex?,
        codingFactoryClosure: @escaping () throws -> RuntimeCoderFactoryProtocol,
        connection: JSONRPCEngine
    ) -> CompoundOperationWrapper<[StakingUnclaimedReward]> {
        let unclaimedRewardsOperation = OperationCombiningService(
            operationManager: OperationManager(operationQueue: operationQueue)
        ) {
            let pagedEra = try exposurePagedEra()
            let validators = try validatorsClosure()

            if pagedEra != nil {
                let wrapper = self.createClaimedBasedWrapper(
                    for: validators,
                    codingFactoryClosure: codingFactoryClosure,
                    connection: connection
                )

                return [wrapper]
            } else {
                let wrapper = self.createLedgerBasedWrapper(
                    for: validators,
                    codingFactoryClosure: codingFactoryClosure,
                    connection: connection
                )

                return [wrapper]
            }
        }.longrunOperation()

        let mergeOperation = ClosureOperation<[StakingUnclaimedReward]> {
            try unclaimedRewardsOperation.extractNoCancellableResultData().flatMap { $0 }
        }

        mergeOperation.addDependency(unclaimedRewardsOperation)

        return CompoundOperationWrapper(targetOperation: mergeOperation, dependencies: [unclaimedRewardsOperation])
    }
}
