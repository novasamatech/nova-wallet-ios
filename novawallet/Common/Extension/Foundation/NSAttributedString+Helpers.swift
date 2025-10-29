import Foundation
import UIKit_iOS
import UIKit

extension NSAttributedString {
    func truncate(maxLength: Int) -> NSAttributedString {
        if length > maxLength, maxLength > 0 {
            let range = NSRange(location: 0, length: maxLength)
            let mutableString = NSMutableAttributedString(attributedString: attributedSubstring(from: range))

            let attributes = mutableString.attributes(at: maxLength - 1, effectiveRange: nil)
            let truncation = NSAttributedString(string: String.readMore, attributes: attributes)

            mutableString.append(truncation)

            return mutableString
        } else {
            return self
        }
    }
}

extension NSAttributedString {
    static func styledAmountString(
        from amount: String,
        intPartFont: UIFont,
        fractionFont: UIFont,
        decimalSeparator: String?
    ) -> NSAttributedString {
        let defaultAttributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: R.color.colorTextPrimary()!,
            .font: intPartFont
        ]

        if
            let lastChar = amount.last?.asciiValue,
            !NSCharacterSet.decimalDigits.contains(UnicodeScalar(lastChar)) {
            return .init(string: amount, attributes: defaultAttributes)
        } else {
            guard let decimalSeparator,
                  let range = amount.range(of: decimalSeparator) else {
                return .init(string: amount, attributes: defaultAttributes)
            }

            let amountAttributedString = NSMutableAttributedString(string: amount)
            let intPartRange = NSRange(amount.startIndex ..< range.lowerBound, in: amount)

            let fractionPartRange = NSRange(range.lowerBound ..< amount.endIndex, in: amount)

            amountAttributedString.setAttributes(
                defaultAttributes,
                range: intPartRange
            )

            amountAttributedString.setAttributes(
                [
                    .foregroundColor: R.color.colorTextSecondary()!,
                    .font: fractionFont
                ],
                range: fractionPartRange
            )

            return amountAttributedString
        }
    }
}
