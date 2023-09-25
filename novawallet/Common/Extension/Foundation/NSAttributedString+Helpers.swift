import Foundation

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
