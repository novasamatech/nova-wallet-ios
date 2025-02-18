import Foundation
import Operation_iOS

protocol TextHeightOperationFactoryProtocol {
    func createOperation(for context: TextHeightCalculationContext) -> BaseOperation<Float>
}

final class TextHeightOperationFactory: TextHeightOperationFactoryProtocol {
    func createOperation(for context: TextHeightCalculationContext) -> BaseOperation<Float> {
        ClosureOperation {
            let text = context.calculatableText

            var height: Float = 0.0

            text.forEach { string in
                height
                    += Float(string.text.estimateHeight(
                        for: string.params.font,
                        width: string.params.availableWidth
                    ))
                    + Float(string.params.topInset)
                    + Float(string.params.bottomInset)
            }

            return height
        }
    }
}
