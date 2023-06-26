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
        let attributedString = NSMutableAttributedString(
            string: model.text,
            attributes: [.foregroundColor: style.textColor,
                         .font: style.font]
        )

        model.accents.forEach { accent in
            if let range = model.text.range(of: accent) {
                let nsRange = NSRange(range, in: model.text)
                attributedString.addAttribute(.foregroundColor, value: style.accentTextColor, range: nsRange)
            }
        }

        attributedText = attributedString
    }
}
