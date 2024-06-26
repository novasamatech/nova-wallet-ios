import UIKit

extension NSAttributedString {
    static func coloredItems(
        _ items: [String],
        formattingClosure: ([String]) -> String,
        color: UIColor
    ) -> NSAttributedString {
        highlightedItems(
            items,
            formattingClosure: formattingClosure,
            highlightingAttributes: [.foregroundColor: color],
            defaultAttributes: nil
        )
    }

    static func highlightedItems(
        _ items: [String],
        formattingClosure: ([String]) -> String,
        highlightingAttributes: [NSAttributedString.Key: Any],
        defaultAttributes: [NSAttributedString.Key: Any]?
    ) -> NSAttributedString {
        let marker = AttributedReplacementStringDecorator.marker
        let decorator = AttributedReplacementStringDecorator(
            pattern: marker,
            replacements: items,
            attributes: highlightingAttributes
        )

        let markers = Array(repeating: marker, count: items.count)
        let template = formattingClosure(markers)

        let attributedString = NSAttributedString(string: template, attributes: defaultAttributes)

        return decorator.decorate(attributedString: attributedString)
    }

    static func coloredFontItems(
        _ items: [String],
        formattingClosure: ([String]) -> String,
        color: UIColor,
        font: UIFont
    ) -> NSAttributedString {
        highlightedItems(
            items,
            formattingClosure: formattingClosure,
            highlightingAttributes: [
                .foregroundColor: color,
                .font: font
            ],
            defaultAttributes: nil
        )
    }
}
