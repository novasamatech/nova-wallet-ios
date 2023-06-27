import UIKit

struct MultiColorTextStyle {
    var textColor: UIColor
    var accentTextColor: UIColor
    var font: UIFont
}

struct AccentTextModel {
    let text: String
    let accents: [String]
}

extension UILabel {
    func bind(
        model: AccentTextModel,
        with style: MultiColorTextStyle
    ) {
        var attributedString = NSAttributedString(
            string: model.text,
            attributes: [.foregroundColor: style.textColor,
                         .font: style.font]
        )

        let highlightingAttributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: style.accentTextColor
        ]

        model.accents.forEach { accent in
            let decorator = HighlightingAttributedStringDecorator(
                pattern: accent,
                attributes: highlightingAttributes
            )

            attributedString = decorator.decorate(attributedString: attributedString)
        }

        attributedText = attributedString
    }
}
