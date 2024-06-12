import Foundation
import Operation_iOS

protocol ParaStakingRewardCalculatorServiceProtocol: ApplicationServiceProtocol {
    func fetchCalculatorOperation() -> BaseOperation<ParaStakingRewardCalculatorEngineProtocol>
}
