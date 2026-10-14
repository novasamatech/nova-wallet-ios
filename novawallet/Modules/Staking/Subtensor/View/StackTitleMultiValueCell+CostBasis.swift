import UIKit

extension StackTitleMultiValueCell {
    func apply<Value>(_ state: SubtensorRowState<Value>, bind: (Value) -> Void) {
        switch state {
        case .hidden:
            isHidden = true
            stopLoadingIfNeeded()
        case .loading:
            isHidden = false
            startLoadingIfNeeded()
        case let .value(value):
            isHidden = false
            stopLoadingIfNeeded()
            bind(value)
        }
    }

    func apply(_ state: SubtensorRowState<String>) {
        apply(state) { rowContentView.valueView.bind(topValue: $0, bottomValue: nil) }
    }

    func bind(costBasisRow viewModel: SubtensorRowState<SubtensorCostBasisValueViewModel>) {
        apply(viewModel) { value in
            topValueLabel.attributedText = value.attributedAmount
            bottomValueLabel.text = value.detail ?? ""
            bottomValueLabel.isHidden = value.detail == nil
        }
    }
}

private extension SubtensorCostBasisValueViewModel {
    var attributedAmount: NSAttributedString {
        let amountAttributes = Self.attributes(font: .regularFootnote, tone: tone)

        guard let arrow = trend?.arrow else {
            return NSAttributedString(string: amount, attributes: amountAttributes)
        }

        let text = NSMutableAttributedString(
            string: arrow.glyph,
            attributes: Self.attributes(font: .caption2, tone: arrow.tone)
        )

        text.append(NSAttributedString(string: " " + amount, attributes: amountAttributes))

        return text
    }

    static func attributes(font: UIFont, tone: SubtensorValueTone) -> [NSAttributedString.Key: Any] {
        var attributes: [NSAttributedString.Key: Any] = [.font: font]
        attributes[.foregroundColor] = tone.textColor

        return attributes
    }
}

extension SubtensorAvgBuyPriceTrend {
    var arrow: (glyph: String, tone: SubtensorValueTone)? {
        switch self {
        case .rising:
            return ("\u{25B2}", .negative)
        case .falling:
            return ("\u{25BC}", .positive)
        case .unchanged:
            return nil
        }
    }
}
