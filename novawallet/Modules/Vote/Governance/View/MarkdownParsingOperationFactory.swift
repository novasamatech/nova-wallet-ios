import Foundation
import RobinHood
import CDMarkdownKit
import UIKit

protocol MarkdownParsingOperationFactoryProtocol {
    func createParseOperation(for string: String, preferredWidth: CGFloat) -> BaseOperation<MarkdownText>
}

final class MarkdownParsingOperationFactory: MarkdownParsingOperationFactoryProtocol {
    let maxSize: Int?

    init(maxSize: Int?) {
        self.maxSize = maxSize
    }

    private func createMarkdownParser(for preferredWidth: CGFloat, imageDetectionEnabled: Bool) -> CDMarkdownParser {
        let textParagraphStyle = NSMutableParagraphStyle()
        textParagraphStyle.paragraphSpacing = 8
        textParagraphStyle.paragraphSpacingBefore = 8
        let listParagraphStyle = NSMutableParagraphStyle()
        listParagraphStyle.paragraphSpacing = 2
        listParagraphStyle.paragraphSpacingBefore = 0
        listParagraphStyle.firstLineHeadIndent = 0
        listParagraphStyle.lineSpacing = 0

        let parser = CDMarkdownParser(
            font: CDFont.systemFont(ofSize: 15),
            fontColor: R.color.colorTextSecondary()!,
            paragraphStyle: textParagraphStyle,
            imageDetectionEnabled: imageDetectionEnabled
        )

        parser.bold.color = R.color.colorTextSecondary()!
        parser.bold.backgroundColor = nil
        parser.header.color = R.color.colorTextPrimary()!
        parser.header.backgroundColor = nil
        parser.list.color = R.color.colorTextSecondary()!
        parser.list.backgroundColor = nil
        parser.list.paragraphStyle = listParagraphStyle
        parser.quote.color = R.color.colorTextSecondary()
        parser.quote.backgroundColor = nil
        parser.link.color = R.color.colorButtonTextAccent()!
        parser.link.backgroundColor = nil
        parser.automaticLink.color = R.color.colorButtonTextAccent()!
        parser.automaticLink.backgroundColor = nil
        parser.italic.color = R.color.colorTextSecondary()!
        parser.italic.backgroundColor = nil
        let codeParagraphStyle = NSMutableParagraphStyle()
        parser.code.font = UIFont.systemFont(ofSize: 15)
        parser.code.color = R.color.colorTextPrimary()!
        parser.code.backgroundColor = UIColor(white: 20.0 / 256.0, alpha: 1.0)
        parser.code.paragraphStyle = codeParagraphStyle
        parser.syntax.font = UIFont.systemFont(ofSize: 15)
        parser.syntax.color = R.color.colorTextPrimary()!
        parser.syntax.backgroundColor = UIColor(white: 20.0 / 256.0, alpha: 1.0)

        // library uses only width internally and adjusts the height of the image
        parser.image.size = CGSize(width: preferredWidth, height: 0)

        return parser
    }

    private func createOperation(
        for string: String,
        preferredWidth: CGFloat,
        maxSize: Int?
    ) -> BaseOperation<MarkdownText> {
        ClosureOperation<MarkdownText> {
            let preprocessed: String
            let isFull: Bool

            let parser: CDMarkdownParser

            if let maxSize = maxSize {
                isFull = string.count <= maxSize
                preprocessed = string.convertToReadMore(after: maxSize)
                parser = self.createMarkdownParser(for: preferredWidth, imageDetectionEnabled: false)
            } else {
                isFull = true
                preprocessed = string
                parser = self.createMarkdownParser(for: preferredWidth, imageDetectionEnabled: true)
            }

            let attributedString = parser.parse(preprocessed)

            let preferredHeight = attributedString.boundingRect(
                with: CGSize(width: preferredWidth, height: 0),
                options: .usesLineFragmentOrigin,
                context: nil
            ).height

            let preferredSize = CGSize(width: preferredWidth, height: preferredHeight)

            return .init(
                originalString: string,
                attributedString: attributedString,
                preferredSize: preferredSize,
                isFull: isFull
            )
        }
    }

    func createParseOperation(for string: String, preferredWidth: CGFloat) -> BaseOperation<MarkdownText> {
        createOperation(for: string, preferredWidth: preferredWidth, maxSize: maxSize)
    }
}

import ZMarkupParser

protocol HtmlParsingOperationFactoryProtocol {
    func createParseOperation(for string: NSAttributedString) -> BaseOperation<NSAttributedString>
}

final class HtmlParsingOperationFactory: HtmlParsingOperationFactoryProtocol {
    private func createParser() -> ZHTMLParser {
        ZHTMLParserBuilder.initWithDefault()
            .set(rootStyle: MarkupStyle(font: MarkupStyleFont(size: 13)))
            .build()
    }

    private func createOperation(
        for string: NSAttributedString
    ) -> BaseOperation<NSAttributedString> {
        ClosureOperation<NSAttributedString> {
            let parser: ZHTMLParser = self.createParser()
            return parser.render(string)
        }
    }

    func createParseOperation(for string: NSAttributedString) -> BaseOperation<NSAttributedString> {
        createOperation(for: string)
    }
}

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
            let markdownResult = try markdownOperation.extractNoCancellableResultData()

            guard let self = self else {
                return CompoundOperationWrapper.createWithResult(markdownResult)
            }

            let htmlParseOperation = self.htmlParsingOperationFactory.createParseOperation(for: markdownResult.attributedString)

            let mergeOperation = ClosureOperation<MarkdownText> {
                let htmlResult = try htmlParseOperation.extractNoCancellableResultData()
                return MarkdownText(
                    originalString: markdownResult.originalString,
                    attributedString: htmlResult,
                    preferredSize: markdownResult.preferredSize,
                    isFull: markdownResult.isFull
                )
            }

            mergeOperation.addDependency(htmlParseOperation)

            return CompoundOperationWrapper<MarkdownText>(
                targetOperation: mergeOperation,
                dependencies: htmlParseOperation.dependencies + markdownOperation.dependencies
            )
        }

        return wrapper
    }
}
