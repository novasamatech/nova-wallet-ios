import Foundation
import Operation_iOS

protocol RewardCalculatorServiceProtocol: ApplicationServiceProtocol {
    func fetchCalculatorOperation() -> BaseOperation<RewardCalculatorEngineProtocol>
}
