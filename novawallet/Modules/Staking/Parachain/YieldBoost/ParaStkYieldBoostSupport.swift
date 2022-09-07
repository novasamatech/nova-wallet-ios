import Foundation
import SubstrateSdk
import RobinHood

protocol ParaStkYieldBoostSupportProtocol {
    func checkSupport(for chainAsset: ChainAsset) -> Bool
    func createAutomationTimeOperationFactory(for chainAsset: ChainAsset) -> AutomationTimeOperationFactoryProtocol?
}

final class ParaStkYieldBoostSupport: ParaStkYieldBoostSupportProtocol {
    let operationQueue: OperationQueue

    init(operationQueue: OperationQueue = OperationManagerFacade.sharedDefaultQueue) {
        self.operationQueue = operationQueue
    }

    func checkSupport(for chainAsset: ChainAsset) -> Bool {
        StakingType(rawType: chainAsset.asset.staking) == .turing
    }

    func createAutomationTimeOperationFactory(for chainAsset: ChainAsset) -> AutomationTimeOperationFactoryProtocol? {
        guard checkSupport(for: chainAsset) else {
            return nil
        }

        let requestFactory = StorageRequestFactory(
            remoteFactory: StorageKeyFactory(),
            operationManager: OperationManager(operationQueue: operationQueue)
        )

        return AutomationTimeOperationFactory(requestFactory: requestFactory)
    }
}
