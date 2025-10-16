import Foundation
import Operation_iOS

protocol MarkupParsingOperationFactoryProtocol {
    func createParseOperation(
        for string: String,
        preferredWidth: CGFloat
    ) -> CompoundOperationWrapper<MarkupAttributedText?>
}

final class MarkupParsingOperationFactory: MarkupParsingOperationFactoryProtocol {
    let markdownParsingOperationFactory: MarkdownParsingOperationFactoryProtocol
    let htmlParsingOperationFactory: HtmlParsingOperationFactoryProtocol
    let operationQueue: OperationQueue
    private lazy var operationManager = OperationManager(operationQueue: operationQueue)

    init(
        markdownParsingOperationFactory: MarkdownParsingOperationFactoryProtocol,
        htmlParsingOperationFactory: HtmlParsingOperationFactoryProtocol,
        operationQueue: OperationQueue
    ) {
        self.operationQueue = operationQueue
        self.markdownParsingOperationFactory = markdownParsingOperationFactory
        self.htmlParsingOperationFactory = htmlParsingOperationFactory
    }

    func createParseOperation(
        for string: String,
        preferredWidth: CGFloat
    ) -> CompoundOperationWrapper<MarkupAttributedText?> {
        let detectionOperation = ClosureOperation<Bool> {
            string.isHtml()
        }

        let markupOperation = OperationCombiningService(
            operationManager: OperationManager(operationQueue: operationQueue)
        ) {
            let isHtml = try detectionOperation.extractNoCancellableResultData()

            let operation: BaseOperation<MarkupAttributedText>

            if isHtml {
                operation = self.htmlParsingOperationFactory.createParseOperation(
                    for: string,
                    preferredWidth: preferredWidth
                )
            } else {
                operation = self.markdownParsingOperationFactory.createParseOperation(
                    for: string,
                    preferredWidth: preferredWidth
                )
            }

            return [CompoundOperationWrapper(targetOperation: operation)]
        }.longrunOperation()

        markupOperation.addDependency(detectionOperation)

        let mergeOperation = ClosureOperation<MarkupAttributedText?> {
            try markupOperation.extractNoCancellableResultData().first
        }

        mergeOperation.addDependency(markupOperation)

        return CompoundOperationWrapper<MarkupAttributedText?>(
            targetOperation: mergeOperation,
            dependencies: [detectionOperation, markupOperation]
        )
    }
}
