import Foundation
import RobinHood

protocol StakingSessionPeriodOperationFactoryProtocol {
    func createOperation(
        dependingOn codingFactoryOperation: BaseOperation<RuntimeCoderFactoryProtocol>
    ) -> BaseOperation<SessionIndex>
}

final class PathStakingSessionPeriodOperationFactory: StakingSessionPeriodOperationFactoryProtocol {
    let defaultSessionPeriod: SessionIndex
    let path: ConstantCodingPath

    init(path: ConstantCodingPath, defaultSessionPeriod: SessionIndex = 50) {
        self.path = path
        self.defaultSessionPeriod = defaultSessionPeriod
    }

    func createOperation(
        dependingOn codingFactoryOperation: BaseOperation<RuntimeCoderFactoryProtocol>
    ) -> BaseOperation<SessionIndex> {
        PrimitiveConstantOperation.operation(
            for: path,
            dependingOn: codingFactoryOperation,
            fallbackValue: defaultSessionPeriod
        )
    }
}
