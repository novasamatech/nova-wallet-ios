import UIKit
import ZMarkupParser
import ZNSTextAttachment
import Operation_iOS

protocol HtmlParsingOperationFactoryProtocol {
    func createParseOperation(
        for string: String,
        preferredWidth: CGFloat
    ) -> BaseOperation<MarkupAttributedText>
}

final class HtmlParsingOperationFactory: HtmlParsingOperationFactoryProtocol {
    let maxSize: Int?

    init(maxSize: Int?) {
        self.maxSize = maxSize
    }

    func createParseOperation(
        for string: String,
        preferredWidth: CGFloat,
        maxSize: Int?
    ) -> BaseOperation<MarkupAttributedText> {
        ClosureOperation<MarkupAttributedText> {
            var builder = ZHTMLParserBuilder()
            var tags = Self.htmlTags

            if maxSize == nil {
                tags.append(Self.imageTag(handler: nil))
            }
            for htmlTagName in tags {
                builder = builder.add(htmlTagName)
            }
            for styleAttribute in ZHTMLParserBuilder.styleAttributes {
                builder = builder.add(styleAttribute)
            }

            var style = MarkupStyle()
            style.font = MarkupStyleFont(UIFont.systemFont(ofSize: 15))
            style.foregroundColor = MarkupStyleColor(color: R.color.colorTextSecondary()!)

            builder = builder.set(rootStyle: style)

            let attributedString: NSAttributedString
            let isFull: Bool

            let parser = builder.build()

            if let maxSize = maxSize {
                let preprocessed = String(string.prefix(4 * maxSize))
                let resultString = parser.render(preprocessed)

                attributedString = resultString.truncate(maxLength: maxSize)
                isFull = resultString.length <= maxSize
            } else {
                isFull = true
                attributedString = parser.render(string)
            }

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

    func createParseOperation(
        for string: String,
        preferredWidth: CGFloat
    ) -> BaseOperation<MarkupAttributedText> {
        createParseOperation(for: string, preferredWidth: preferredWidth, maxSize: maxSize)
    }
}

extension HtmlParsingOperationFactory {
    static var htmlTags: [HTMLTagName] {
        [
            A_HTMLTagName(),
            B_HTMLTagName(),
            BR_HTMLTagName(),
            DIV_HTMLTagName(),
            HR_HTMLTagName(),
            I_HTMLTagName(),
            LI_HTMLTagName(),
            OL_HTMLTagName(),
            P_HTMLTagName(),
            SPAN_HTMLTagName(),
            STRONG_HTMLTagName(),
            U_HTMLTagName(),
            UL_HTMLTagName(),
            DEL_HTMLTagName(),
            TR_HTMLTagName(),
            TD_HTMLTagName(),
            TH_HTMLTagName(),
            TABLE_HTMLTagName(),
            FONT_HTMLTagName(),
            H1_HTMLTagName(),
            H2_HTMLTagName(),
            H3_HTMLTagName(),
            H4_HTMLTagName(),
            H5_HTMLTagName(),
            H6_HTMLTagName(),
            S_HTMLTagName(),
            PRE_HTMLTagName(),
            CODE_HTMLTagName(),
            EM_HTMLTagName(),
            BLOCKQUOTE_HTMLTagName()
        ]
    }

    static func imageTag(handler: ZNSTextAttachmentHandler?) -> HTMLTagName {
        IMG_HTMLTagName(handler: handler)
    }
}
