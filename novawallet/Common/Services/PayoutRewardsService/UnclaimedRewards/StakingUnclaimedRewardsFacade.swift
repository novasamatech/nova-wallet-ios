import Foundation
import SubstrateSdk
import RobinHood

struct StakingUnclaimedReward {
    let accountId: AccountId
    let era: EraIndex
    let page: Staking.ValidatorPage
}

protocol StakingUnclaimedRewardsFacadeProtocol {
    func createWrapper(
        for accountId: AccountId,
        validatorsClosure: @escaping () throws -> [StakingValidatorExposure],
        exposurePagedEra: @escaping () throws -> EraIndex?,
        codingFactoryClosure: @escaping () throws -> RuntimeCoderFactoryProtocol,
        connection: JSONRPCEngine
    ) -> CompoundOperationWrapper<[StakingUnclaimedReward]>
}

protocol StakingUnclaimedRewardsOperationFactoryProtocol {
    func createWrapper(
        for accountId: AccountId,
        validatorsClosure: @escaping () throws -> [StakingValidatorExposure],
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
        for accountId: AccountId,
        validators: [StakingValidatorExposure],
        codingFactoryClosure: @escaping () throws -> RuntimeCoderFactoryProtocol,
        connection: JSONRPCEngine
    ) -> CompoundOperationWrapper<[StakingUnclaimedReward]> {
        StakingLedgerUnclaimedRewardsFactory(
            requestFactory: requestFactory
        ).createWrapper(
            for: accountId,
            validatorsClosure: { validators },
            codingFactoryClosure: codingFactoryClosure,
            connection: connection
        )
    }

    func createClaimedBasedWrapper(
        for accountId: AccountId,
        validators: [StakingValidatorExposure],
        codingFactoryClosure: @escaping () throws -> RuntimeCoderFactoryProtocol,
        connection: JSONRPCEngine
    ) -> CompoundOperationWrapper<[StakingUnclaimedReward]> {
        StakingClaimedRewardsOperationFactory(
            requestFactory: requestFactory
        ).createWrapper(
            for: accountId,
            validatorsClosure: { validators },
            codingFactoryClosure: codingFactoryClosure,
            connection: connection
        )
    }
}

extension StakingUnclaimedRewardsFacade: StakingUnclaimedRewardsFacadeProtocol {
    func createWrapper(
        for accountId: AccountId,
        validatorsClosure: @escaping () throws -> [StakingValidatorExposure],
        exposurePagedEra: @escaping () throws -> EraIndex?,
        codingFactoryClosure: @escaping () throws -> RuntimeCoderFactoryProtocol,
        connection: JSONRPCEngine
    ) -> CompoundOperationWrapper<[StakingUnclaimedReward]> {
        let unclaimedRewardsOperation = OperationCombiningService(
            operationManager: OperationManager(operationQueue: operationQueue)
        ) {
            let pagedEra = try exposurePagedEra()
            let validators = try validatorsClosure()

            let stakingLedgerItems = validators.filter { validator in
                guard let pagedEra = pagedEra else {
                    return true
                }

                return validator.era < pagedEra
            }

            let claimedBasedItems = validators.filter { validator in
                guard let pagedEra = pagedEra else {
                    return false
                }

                return validator.era >= pagedEra
            }

            var wrappers: [CompoundOperationWrapper<[StakingUnclaimedReward]>] = []

            if !stakingLedgerItems.isEmpty {
                let wrapper = self.createLedgerBasedWrapper(
                    for: accountId,
                    validators: stakingLedgerItems,
                    codingFactoryClosure: codingFactoryClosure,
                    connection: connection
                )

                wrappers.append(wrapper)
            }

            if !claimedBasedItems.isEmpty {
                let wrapper = self.createClaimedBasedWrapper(
                    for: accountId,
                    validators: claimedBasedItems,
                    codingFactoryClosure: codingFactoryClosure,
                    connection: connection
                )

                wrappers.append(wrapper)
            }

            return wrappers
        }.longrunOperation()

        let mergeOperation = ClosureOperation<[StakingUnclaimedReward]> {
            try unclaimedRewardsOperation.extractNoCancellableResultData().flatMap { $0 }
        }

        mergeOperation.addDependency(unclaimedRewardsOperation)

        return CompoundOperationWrapper(targetOperation: mergeOperation, dependencies: [unclaimedRewardsOperation])
    }
}
