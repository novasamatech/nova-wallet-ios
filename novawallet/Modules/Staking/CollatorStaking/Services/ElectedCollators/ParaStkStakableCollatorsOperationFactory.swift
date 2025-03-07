import Foundation
import Operation_iOS

final class ParaStkStakableCollatorsOperationFactory {
    let collatorsOperationFactory: ParaStkCollatorsOperationFactoryProtocol
    let collatorService: ParachainStakingCollatorServiceProtocol
    let rewardsService: CollatorStakingRewardCalculatorServiceProtocol

    init(
        collatorsOperationFactory: ParaStkCollatorsOperationFactoryProtocol,
        collatorService: ParachainStakingCollatorServiceProtocol,
        rewardsService: CollatorStakingRewardCalculatorServiceProtocol
    ) {
        self.collatorsOperationFactory = collatorsOperationFactory
        self.collatorService = collatorService
        self.rewardsService = rewardsService
    }
}

extension ParaStkStakableCollatorsOperationFactory: CollatorStakingStakableFactoryProtocol {
    func stakableCollatorsWrapper() -> CompoundOperationWrapper<[CollatorStakingSelectionInfoProtocol]> {
        let wrapper = collatorsOperationFactory.electedCollatorsInfoOperation(
            for: collatorService,
            rewardService: rewardsService
        )

        let mappingOperation = ClosureOperation<[CollatorStakingSelectionInfoProtocol]> {
            try wrapper.targetOperation.extractNoCancellableResultData()
        }

        mappingOperation.addDependency(wrapper.targetOperation)

        return wrapper.insertingTail(operation: mappingOperation)
    }
}
