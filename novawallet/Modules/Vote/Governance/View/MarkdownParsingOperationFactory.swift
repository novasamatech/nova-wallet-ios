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

        let parser = CDMarkdownParser(
            font: CDFont.systemFont(ofSize: 15),
            fontColor: R.color.colorTransparentText()!,
            paragraphStyle: textParagraphStyle,
            imageDetectionEnabled: imageDetectionEnabled
        )

        parser.bold.color = R.color.colorTransparentText()!
        parser.bold.backgroundColor = nil
        parser.header.color = R.color.colorWhite()!
        parser.header.backgroundColor = nil
        parser.list.color = R.color.colorTransparentText()!
        parser.list.backgroundColor = nil
        parser.quote.color = R.color.colorTransparentText()
        parser.quote.backgroundColor = nil
        parser.link.color = R.color.colorNovaBlue()!
        parser.link.backgroundColor = nil
        parser.automaticLink.color = R.color.colorNovaBlue()!
        parser.automaticLink.backgroundColor = nil
        parser.italic.color = R.color.colorTransparentText()!
        parser.italic.backgroundColor = nil
        let codeParagraphStyle = NSMutableParagraphStyle()
        parser.code.font = UIFont.systemFont(ofSize: 15)
        parser.code.color = R.color.colorWhite()!
        parser.code.backgroundColor = UIColor(white: 20.0 / 256.0, alpha: 1.0)
        parser.code.paragraphStyle = codeParagraphStyle
        parser.syntax.font = UIFont.systemFont(ofSize: 15)
        parser.syntax.color = R.color.colorWhite()!
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
