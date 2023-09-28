import Foundation
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
    func replacingAttachment<TAttachment, TNewAttachment>(
        mapClosure: (TAttachment) -> TNewAttachment?
    ) -> NSAttributedString where TNewAttachment: NSTextAttachment {
        let mutableAttributedString = NSMutableAttributedString(attributedString: self)
        let range = NSRange(location: 0, length: mutableAttributedString.length)
        mutableAttributedString.enumerateAttribute(
            .attachment,
            in: range,
            options: []
        ) { value, effectiveRange, _ in
            if let attachment = value as? TAttachment, let newAttachment = mapClosure(attachment) {
                mutableAttributedString.deleteCharacters(in: effectiveRange)
                mutableAttributedString.insert(.init(attachment: newAttachment), at: effectiveRange.location)
            }
        }

        return mutableAttributedString
    }
}
