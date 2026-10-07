import Foundation
import Operation_iOS

protocol TextHeightOperationFactoryProtocol {
    func createOperation(for context: TextHeightCalculationContext) -> BaseOperation<Float>
}

final class TextHeightOperationFactory: TextHeightOperationFactoryProtocol {
    func createOperation(for context: TextHeightCalculationContext) -> BaseOperation<Float> {
        ClosureOperation {
            context.estimatedHeight
        }
    }
}
