import RobinHood

protocol MarkupParsingOperationFactoryProtocol {
    func createParseOperation(for string: String, preferredWidth: CGFloat) -> CompoundOperationWrapper<MarkdownText?>
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

    func createParseOperation(for string: String, preferredWidth: CGFloat) -> CompoundOperationWrapper<MarkdownText?> {
        let markdownOperation = markdownParsingOperationFactory.createParseOperation(
            for: string,
            preferredWidth: preferredWidth
        )

        let wrapper: CompoundOperationWrapper<MarkdownText?> = OperationCombiningService.compoundWrapper(
            operationManager: operationManager
        ) { [weak self] in
            let markdownText = try markdownOperation.extractNoCancellableResultData()

            guard let self = self else {
                return CompoundOperationWrapper.createWithResult(markdownText)
            }

            let htmlParseOperation = self.htmlParsingOperationFactory
                .createParseOperation(for: markdownText.attributedString)

            let mergeOperation = ClosureOperation<MarkdownText> {
                let htmlText = try htmlParseOperation.extractNoCancellableResultData()
                return MarkdownText(
                    originalString: markdownText.originalString,
                    attributedString: htmlText,
                    preferredSize: markdownText.preferredSize,
                    isFull: markdownText.isFull
                )
            }

            mergeOperation.addDependency(htmlParseOperation)

            return CompoundOperationWrapper<MarkdownText>(
                targetOperation: mergeOperation,
                dependencies: [htmlParseOperation]
            )
        }

        wrapper.addDependency(operations: [markdownOperation])

        return CompoundOperationWrapper<MarkdownText?>(
            targetOperation: wrapper.targetOperation,
            dependencies: [markdownOperation] + wrapper.dependencies
        )
    }
}
