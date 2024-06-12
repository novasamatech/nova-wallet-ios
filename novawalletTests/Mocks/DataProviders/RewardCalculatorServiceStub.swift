import Foundation
@testable import novawallet
import Operation_iOS

final class RewardCalculatorServiceStub: RewardCalculatorServiceProtocol {
    let engine: RewardCalculatorEngineProtocol

    init(engine: RewardCalculatorEngineProtocol) {
        self.engine = engine
    }

    func setup() {}

    func throttle() {}

    func fetchCalculatorOperation() -> BaseOperation<RewardCalculatorEngineProtocol> {
        ClosureOperation { self.engine }
    }
}
