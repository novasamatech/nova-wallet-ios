import Foundation
import RobinHood
import BigInt

protocol ParaStkNetworkInfoOperationFactoryProtocol {
    func networkStakingOperation(
        for collatorService: ParachainStakingCollatorServiceProtocol,
        rewardCalculatorService: ParaStakingRewardCalculatorServiceProtocol,
        runtimeService: RuntimeCodingServiceProtocol
    ) -> CompoundOperationWrapper<ParachainStaking.NetworkInfo>
}

final class ParaStkNetworkInfoOperationFactory {
    let durationFactory: ParaStkDurationOperationFactoryProtocol

    init(durationFactory: ParaStkDurationOperationFactoryProtocol) {
        self.durationFactory = durationFactory
    }

    private func deriveMinimalStake(
        from collatorsInfo: SelectedRoundCollators,
        limitedBy maxDelegators: Int
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
        rewardCalculatorService: ParaStakingRewardCalculatorServiceProtocol,
        runtimeService: RuntimeCodingServiceProtocol
    ) -> CompoundOperationWrapper<ParachainStaking.NetworkInfo> {
        let codingFactoryOperation = runtimeService.fetchCoderFactoryOperation()

        let minStakeOperation: BaseOperation<BigUInt> = PrimitiveConstantOperation.operation(
            for: ParachainStaking.minDelegatorStk,
            dependingOn: codingFactoryOperation
        )

        let maxDeletorsOperation: BaseOperation<Int> = PrimitiveConstantOperation
            .operation(
                for: ParachainStaking.maxTopDelegationsPerCandidate,
                dependingOn: codingFactoryOperation
            )

        [minStakeOperation, maxDeletorsOperation].forEach {
            $0.addDependency(codingFactoryOperation)
        }

        let collatorsOperation = collatorService.fetchInfoOperation()
        let rewardEngineOperation = rewardCalculatorService.fetchCalculatorOperation()
        let stakingDurationWrapper = durationFactory.createDurationOperation(from: runtimeService)

        let mapOperation = ClosureOperation<ParachainStaking.NetworkInfo> {
            let minStake = try minStakeOperation.extractNoCancellableResultData()
            let maxDelegators = try maxDeletorsOperation.extractNoCancellableResultData()
            let collatorsInfo = try collatorsOperation.extractNoCancellableResultData()
            let rewardEngine = try rewardEngineOperation.extractNoCancellableResultData()
            let stakingDuration = try stakingDurationWrapper.targetOperation
                .extractNoCancellableResultData()

            let activeDelegatorsCount = self.deriveActiveDelegatorsCount(from: collatorsInfo)
            let minDelegatorStake = self.deriveMinimalStake(
                from: collatorsInfo,
                limitedBy: maxDelegators
            )

            return ParachainStaking.NetworkInfo(
                totalStake: rewardEngine.totalStaked,
                minStakeForRewards: minDelegatorStake,
                minTechStake: minStake,
                activeDelegatorsCount: activeDelegatorsCount,
                stakingDuration: stakingDuration
            )
        }

        let regularOperations = [
            codingFactoryOperation,
            minStakeOperation,
            maxDeletorsOperation,
            collatorsOperation,
            rewardEngineOperation
        ]

        let dependencies = regularOperations + stakingDurationWrapper.allOperations

        dependencies.forEach { mapOperation.addDependency($0) }

        return CompoundOperationWrapper(
            targetOperation: mapOperation,
            dependencies: dependencies
        )
    }
}
