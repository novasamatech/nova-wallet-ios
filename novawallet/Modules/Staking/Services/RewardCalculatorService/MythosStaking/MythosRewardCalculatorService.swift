import Foundation
import Operation_iOS

// TODO: Implement in separate task
final class MythosRewardCalculatorService {}

extension MythosRewardCalculatorService: CollatorStakingRewardCalculatorServiceProtocol {
    func setup() {}

    func throttle() {}

    func fetchCalculatorOperation() -> BaseOperation<CollatorStakingRewardCalculatorEngineProtocol> {
        ClosureOperation {
            MythosRewardCalculatorEngine()
        }
    }
}
