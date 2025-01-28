import Foundation
import Operation_iOS
import BigInt

protocol ParaStkNetworkInfoOperationFactoryProtocol {
    func networkStakingOperation(
        for collatorService: ParachainStakingCollatorServiceProtocol,
        rewardCalculatorService: CollatorStakingRewardCalculatorServiceProtocol,
        runtimeService: RuntimeCodingServiceProtocol
    ) -> CompoundOperationWrapper<ParachainStaking.NetworkInfo>
}

final class ParaStkNetworkInfoOperationFactory {
    private func deriveMinimalStake(
        from collatorsInfo: SelectedRoundCollators,
        limitedBy maxDelegators: UInt32
    ) -> BigUInt {
        let allFull = collatorsInfo.collators.allSatisfy { collator in
            collator.snapshot.delegations.count == maxDelegators
        }

        guard allFull else {
            return BigUInt(0)
        }

        return collatorsInfo.collators.map {
            $0.snapshot.delegations.last?.amount ?? BigUInt(0)
        }.min() ?? BigUInt(0)
    }

    private func deriveActiveDelegatorsCount(
        from collatorsInfo: SelectedRoundCollators
    ) -> Int {
        collatorsInfo.collators.reduce(into: Set<AccountId>()) { result, collator in
            collator.snapshot.delegations.forEach { delegation in
                result.insert(delegation.owner)
            }
        }.count
    }
}

extension ParaStkNetworkInfoOperationFactory: ParaStkNetworkInfoOperationFactoryProtocol {
    func networkStakingOperation(
        for collatorService: ParachainStakingCollatorServiceProtocol,
        rewardCalculatorService: CollatorStakingRewardCalculatorServiceProtocol,
        runtimeService: RuntimeCodingServiceProtocol
    ) -> CompoundOperationWrapper<ParachainStaking.NetworkInfo> {
        let codingFactoryOperation = runtimeService.fetchCoderFactoryOperation()

        let minStakeOperation: BaseOperation<BigUInt> = PrimitiveConstantOperation.operation(
            oneOfPaths: [ParachainStaking.minDelegatorStk, ParachainStaking.minDelegation],
            dependingOn: codingFactoryOperation
        )

        let maxDelegatorsOperation: BaseOperation<UInt32> = PrimitiveConstantOperation.operation(
            for: ParachainStaking.maxTopDelegationsPerCandidate,
            dependingOn: codingFactoryOperation
        )

        let constantsOperations = [minStakeOperation, maxDelegatorsOperation]
        constantsOperations.forEach { $0.addDependency(codingFactoryOperation) }

        let collatorsOperation = collatorService.fetchInfoOperation()
        let rewardEngineOperation = rewardCalculatorService.fetchCalculatorOperation()

        let mapOperation = ClosureOperation<ParachainStaking.NetworkInfo> {
            let minStake = try minStakeOperation.extractNoCancellableResultData()
            let maxDelegators = try maxDelegatorsOperation.extractNoCancellableResultData()
            let collatorsInfo = try collatorsOperation.extractNoCancellableResultData()
            let rewardEngine = try rewardEngineOperation.extractNoCancellableResultData()

            let activeDelegatorsCount = self.deriveActiveDelegatorsCount(from: collatorsInfo)
            let minDelegatorStake = self.deriveMinimalStake(from: collatorsInfo, limitedBy: maxDelegators)

            return ParachainStaking.NetworkInfo(
                totalStake: rewardEngine.totalStaked,
                minStakeForRewards: minDelegatorStake,
                minTechStake: minStake,
                maxRewardableDelegators: maxDelegators,
                activeDelegatorsCount: activeDelegatorsCount
            )
        }

        let dependencies = [
            codingFactoryOperation,
            minStakeOperation,
            maxDelegatorsOperation,
            collatorsOperation,
            rewardEngineOperation
        ]

        dependencies.forEach { mapOperation.addDependency($0) }

        return CompoundOperationWrapper(targetOperation: mapOperation, dependencies: dependencies)
    }
}
