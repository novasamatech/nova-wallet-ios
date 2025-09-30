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
        let attributedString = NSAttributedString(
            string: model.text,
            attributes: [.foregroundColor: style.textColor,
                         .font: style.font]
        )

        let highlightingAttributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: style.accentTextColor
        ]

        let decorators = model.accents.map {
            HighlightingAttributedStringDecorator(
                pattern: $0,
                attributes: highlightingAttributes,
                includeSeparator: true
            )
        }

        attributedText = CompoundAttributedStringDecorator(decorators: decorators)
            .decorate(attributedString: attributedString)
    }
}
