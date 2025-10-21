import Foundation
import SubstrateSdk
import Operation_iOS
import BigInt

struct StakingValidatorExposure {
    let accountId: AccountId
    let era: Staking.EraIndex
    let totalStake: BigUInt
    let ownStake: BigUInt
    let pages: [[Staking.IndividualExposure]]

    func others() -> [Staking.IndividualExposure] {
        pages.flatMap { $0 }
    }
}

protocol StakingValidatorExposureFacadeProtocol {
    func createWrapper(
        dependingOn validatorsClosure: @escaping () throws -> Set<ResolvedValidatorEra>,
        exposurePagedEra: @escaping () throws -> Staking.EraIndex?,
        codingFactoryClosure: @escaping () throws -> RuntimeCoderFactoryProtocol,
        connection: JSONRPCEngine
    ) -> CompoundOperationWrapper<[StakingValidatorExposure]>
}

protocol StakingValidatorExposureFactoryProtocol {
    func createWrapper(
        dependingOn validatorsClosure: @escaping () throws -> [ResolvedValidatorEra],
        codingFactoryClosure: @escaping () throws -> RuntimeCoderFactoryProtocol,
        connection: JSONRPCEngine
    ) -> CompoundOperationWrapper<[StakingValidatorExposure]>
}

final class StakingValidatorExposureFacade {
    let operationQueue: OperationQueue
    let requestFactory: StorageRequestFactoryProtocol

    init(operationQueue: OperationQueue, requestFactory: StorageRequestFactoryProtocol) {
        self.operationQueue = operationQueue
        self.requestFactory = requestFactory
    }

    private func createEraStakersWrapper(
        for validators: [ResolvedValidatorEra],
        codingFactoryClosure: @escaping () throws -> RuntimeCoderFactoryProtocol,
        connection: JSONRPCEngine
    ) -> CompoundOperationWrapper<[StakingValidatorExposure]> {
        StakingEraStakersExposureFactory(requestFactory: requestFactory).createWrapper(
            dependingOn: { validators },
            codingFactoryClosure: codingFactoryClosure,
            connection: connection
        )
    }

    private func createEraStakersPagedWrapper(
        for validators: [ResolvedValidatorEra],
        codingFactoryClosure: @escaping () throws -> RuntimeCoderFactoryProtocol,
        connection: JSONRPCEngine
    ) -> CompoundOperationWrapper<[StakingValidatorExposure]> {
        StakingPagedExposureFactory(requestFactory: requestFactory).createWrapper(
            dependingOn: { validators },
            codingFactoryClosure: codingFactoryClosure,
            connection: connection
        )
    }
}

extension StakingValidatorExposureFacade: StakingValidatorExposureFacadeProtocol {
    func createWrapper(
        dependingOn validatorsClosure: @escaping () throws -> Set<ResolvedValidatorEra>,
        exposurePagedEra: @escaping () throws -> Staking.EraIndex?,
        codingFactoryClosure: @escaping () throws -> RuntimeCoderFactoryProtocol,
        connection: JSONRPCEngine
    ) -> CompoundOperationWrapper<[StakingValidatorExposure]> {
        let exposuresOperation = OperationCombiningService(
            operationManager: OperationManager(operationQueue: operationQueue)
        ) {
            let pagedEra = try exposurePagedEra()
            let validatorEras = try validatorsClosure()

            let eraStakersItems = validatorEras.filter { item in
                guard let pagedEra = pagedEra else {
                    return true
                }

                return item.era < pagedEra
            }

            let pagedItems = validatorEras.filter { item in
                guard let pagedEra = pagedEra else {
                    return false
                }

                return item.era >= pagedEra
            }

            var wrappers: [CompoundOperationWrapper<[StakingValidatorExposure]>] = []

            if !eraStakersItems.isEmpty {
                let wrapper = self.createEraStakersWrapper(
                    for: Array(eraStakersItems),
                    codingFactoryClosure: codingFactoryClosure,
                    connection: connection
                )

                wrappers.append(wrapper)
            }

            if !pagedItems.isEmpty {
                let wrapper = self.createEraStakersPagedWrapper(
                    for: Array(pagedItems),
                    codingFactoryClosure: codingFactoryClosure,
                    connection: connection
                )

                wrappers.append(wrapper)
            }

            return wrappers
        }.longrunOperation()

        let mergeOperation = ClosureOperation<[StakingValidatorExposure]> {
            try exposuresOperation.extractNoCancellableResultData().flatMap { $0 }
        }

        mergeOperation.addDependency(exposuresOperation)

        return CompoundOperationWrapper(targetOperation: mergeOperation, dependencies: [exposuresOperation])
    }
}
