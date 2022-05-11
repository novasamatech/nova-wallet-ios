import Foundation
import RobinHood

protocol ParaStakingRewardCalculatorServiceProtocol: ApplicationServiceProtocol {
    func fetchCalculatorOperation() -> BaseOperation<ParaStakingRewardCalculatorEngineProtocol>
}
