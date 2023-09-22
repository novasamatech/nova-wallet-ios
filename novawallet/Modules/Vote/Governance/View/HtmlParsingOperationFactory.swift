import ZMarkupParser
import ZNSTextAttachment
import RobinHood

protocol HtmlParsingOperationFactoryProtocol {
    func createParseOperation(for string: NSAttributedString) -> BaseOperation<NSAttributedString>
}

final class HtmlParsingOperationFactory: HtmlParsingOperationFactoryProtocol {
    let includeImages: Bool

    init(includeImages: Bool = true) {
        self.includeImages = includeImages
    }

    private func style() -> MarkupStyle {
        let textParagraphStyle = NSMutableParagraphStyle()
        textParagraphStyle.paragraphSpacing = 8
        textParagraphStyle.paragraphSpacingBefore = 8

        var style = MarkupStyle()
        style.font = MarkupStyleFont(UIFont.systemFont(ofSize: 15))
        style.paragraphStyle = MarkupStyleParagraphStyle(textParagraphStyle)
        style.foregroundColor = MarkupStyleColor(color: R.color.colorTextSecondary()!)

        return style
    }

    private func createParser() -> ZHTMLParser {
        var builder = ZHTMLParserBuilder()
        var tags = Self.htmlTags
        if includeImages {
            tags.append(Self.imageTag(handler: nil))
        }
        for htmlTagName in tags {
            builder = builder.add(htmlTagName)
        }
        for styleAttribute in ZHTMLParserBuilder.styleAttributes {
            builder = builder.add(styleAttribute)
        }
        builder = builder.set(rootStyle: style())

        return builder.build()
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
