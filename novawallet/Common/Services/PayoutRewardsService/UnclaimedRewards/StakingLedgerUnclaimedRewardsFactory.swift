import Foundation
import Operation_iOS
import SubstrateSdk

final class StakingLedgerUnclaimedRewardsFactory {
    let requestFactory: StorageRequestFactoryProtocol

    init(requestFactory: StorageRequestFactoryProtocol) {
        self.requestFactory = requestFactory
    }

    private func createFetchAndMapOperation<T: Encodable, R: Decodable>(
        dependingOn keyParamsClosure: @escaping () throws -> [T],
        codingFactoryClosure: @escaping () throws -> RuntimeCoderFactoryProtocol,
        connection: JSONRPCEngine,
        path: StorageCodingPath
    ) -> CompoundOperationWrapper<[R]> {
        let wrapper: CompoundOperationWrapper<[StorageResponse<R>]> = requestFactory.queryItems(
            engine: connection,
            keyParams: keyParamsClosure,
            factory: codingFactoryClosure,
            storagePath: path
        )

        let mapOperation = ClosureOperation<[R]> {
            try wrapper.targetOperation.extractNoCancellableResultData().compactMap(\.value)
        }

        wrapper.allOperations.forEach { mapOperation.addDependency($0) }

        return CompoundOperationWrapper(targetOperation: mapOperation, dependencies: wrapper.allOperations)
    }

    func createUnclaimedErasOperation(
        ledgersClosure: @escaping () throws -> [Staking.Ledger],
        validatorsClosure: @escaping () throws -> [StakingValidatorExposure]
    ) -> BaseOperation<[StakingUnclaimedReward]> {
        ClosureOperation<[StakingUnclaimedReward]> {
            let ledgers = try ledgersClosure()

            let indexedValidator = try validatorsClosure().reduce(
                into: [AccountId: Set<Staking.EraIndex>]()
            ) { accum, item in
                let currentEras = accum[item.accountId] ?? Set()
                accum[item.accountId] = currentEras.union([item.era])
            }

            return ledgers.flatMap { ledger in
                guard let validatorEras = indexedValidator[ledger.stash] else {
                    return [StakingUnclaimedReward]()
                }

                let erasClaimedRewards: Set<UInt32> = Set(ledger.claimedRewardsOrEmpty.map(\.value))
                let unclaimedEras = validatorEras.subtracting(erasClaimedRewards)

                return unclaimedEras.map { era in
                    StakingUnclaimedReward(accountId: ledger.stash, era: era, pages: [0])
                }
            }
        }
    }
}

extension StakingLedgerUnclaimedRewardsFactory: StakingUnclaimedRewardsOperationFactoryProtocol {
    func createWrapper(
        for validatorsClosure: @escaping () throws -> [StakingValidatorExposure],
        codingFactoryClosure: @escaping () throws -> RuntimeCoderFactoryProtocol,
        connection: JSONRPCEngine
    ) -> CompoundOperationWrapper<[StakingUnclaimedReward]> {
        let validatorIdsClosure: () throws -> [AccountId] = {
            try validatorsClosure().map(\.accountId).distinct()
        }

        let controllersWrapper: CompoundOperationWrapper<[Data]> = createFetchAndMapOperation(
            dependingOn: validatorIdsClosure,
            codingFactoryClosure: codingFactoryClosure,
            connection: connection,
            path: Staking.controller
        )

        let controllersClosure: () throws -> [AccountId] = {
            try controllersWrapper.targetOperation.extractNoCancellableResultData()
        }

        let ledgersWrapper: CompoundOperationWrapper<[Staking.Ledger]> = createFetchAndMapOperation(
            dependingOn: controllersClosure,
            codingFactoryClosure: codingFactoryClosure,
            connection: connection,
            path: Staking.stakingLedger
        )

        ledgersWrapper.addDependency(wrapper: controllersWrapper)

        let unclaimedRewardsOperation = createUnclaimedErasOperation(
            ledgersClosure: { try ledgersWrapper.targetOperation.extractNoCancellableResultData() },
            validatorsClosure: validatorsClosure
        )

        unclaimedRewardsOperation.addDependency(ledgersWrapper.targetOperation)

        let dependencies = controllersWrapper.allOperations + ledgersWrapper.allOperations

        return CompoundOperationWrapper(targetOperation: unclaimedRewardsOperation, dependencies: dependencies)
    }
}
