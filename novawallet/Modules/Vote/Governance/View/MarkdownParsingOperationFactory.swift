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
