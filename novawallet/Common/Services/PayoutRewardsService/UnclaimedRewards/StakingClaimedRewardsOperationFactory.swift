import Foundation
import SubstrateSdk
import RobinHood

final class StakingClaimedRewardsOperationFactory {
    let requestFactory: StorageRequestFactoryProtocol

    init(requestFactory: StorageRequestFactoryProtocol) {
        self.requestFactory = requestFactory
    }

    private func createClaimedPagesWrapper(
        for validatorsClosure: @escaping () throws -> [StakingValidatorExposure],
        codingFactoryClosure: @escaping () throws -> RuntimeCoderFactoryProtocol,
        connection: JSONRPCEngine
    ) -> CompoundOperationWrapper<[ResolvedValidatorEra: Set<Staking.ValidatorPage>]> {
        let fetchWrapper: CompoundOperationWrapper<[StorageResponse<[StringScaleMapper<Staking.ValidatorPage>]>]>
        fetchWrapper = requestFactory.queryItems(
            engine: connection,
            keyParams1: { try validatorsClosure().map(\.era) },
            keyParams2: { try validatorsClosure().map(\.accountId) },
            factory: codingFactoryClosure,
            storagePath: Staking.claimedRewards
        )

        let mergeOperation = ClosureOperation<[ResolvedValidatorEra: Set<Staking.ValidatorPage>]> {
            let validators = try validatorsClosure()
            let responses = try fetchWrapper.targetOperation.extractNoCancellableResultData()

            return zip(validators, responses).reduce(
                into: [ResolvedValidatorEra: Set<Staking.ValidatorPage>]()
            ) { accum, pair in
                let validatorEra = ResolvedValidatorEra(validator: pair.0.accountId, era: pair.0.era)

                guard let pages = pair.1.value else {
                    return
                }

                accum[validatorEra] = Set(pages.map(\.value))
            }
        }

        mergeOperation.addDependency(fetchWrapper.targetOperation)

        return CompoundOperationWrapper(
            targetOperation: mergeOperation,
            dependencies: fetchWrapper.allOperations
        )
    }
}

extension StakingClaimedRewardsOperationFactory: StakingUnclaimedRewardsOperationFactoryProtocol {
    func createWrapper(
        for validatorsClosure: @escaping () throws -> [StakingValidatorExposure],
        codingFactoryClosure: @escaping () throws -> RuntimeCoderFactoryProtocol,
        connection: JSONRPCEngine
    ) -> CompoundOperationWrapper<[StakingUnclaimedReward]> {
        let claimedPagesWrapper = createClaimedPagesWrapper(
            for: validatorsClosure,
            codingFactoryClosure: codingFactoryClosure,
            connection: connection
        )

        let mergeOperation = ClosureOperation<[StakingUnclaimedReward]> {
            let allClaimedPages = try claimedPagesWrapper.targetOperation.extractNoCancellableResultData()
            let exposures = try validatorsClosure()

            return exposures.compactMap { exposure in
                let validatorEra = ResolvedValidatorEra(validator: exposure.accountId, era: exposure.era)

                let allPages = (0 ..< exposure.pages.count).map { Staking.ValidatorPage($0) }
                let claimedPages = allClaimedPages[validatorEra] ?? Set()
                let unclaimedPages = Set(allPages).subtracting(claimedPages)

                guard !unclaimedPages.isEmpty else {
                    return nil
                }

                return StakingUnclaimedReward(
                    accountId: validatorEra.validator,
                    era: validatorEra.era,
                    pages: unclaimedPages
                )
            }
        }

        mergeOperation.addDependency(claimedPagesWrapper.targetOperation)

        return CompoundOperationWrapper(
            targetOperation: mergeOperation,
            dependencies: claimedPagesWrapper.allOperations
        )
    }
}
