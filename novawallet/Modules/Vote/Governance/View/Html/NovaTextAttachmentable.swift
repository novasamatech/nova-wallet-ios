import ZMarkupParser
import ZNSTextAttachment

public protocol NovaTextAttachmentable: AnyObject {
    func replace(attachment: NovaImageTextAttachment, with resizableAttachment: ZResizableNSTextAttachment)
}

extension NSTextStorage: NovaTextAttachmentable {
    public func replace(
        attachment: NovaImageTextAttachment,
        with resizableAttachment: ZResizableNSTextAttachment
    ) {
        let attributedString = self
        let mutableAttributedString = NSMutableAttributedString(attributedString: attributedString)
        let range = NSRange(location: 0, length: mutableAttributedString.string.utf16.count)
        mutableAttributedString.enumerateAttribute(.attachment, in: range, options: []) { value, effectiveRange, _ in
            guard (value as? NovaImageTextAttachment) == attachment else {
                return
            }
            mutableAttributedString.deleteCharacters(in: effectiveRange)
            mutableAttributedString.insert(
                NSAttributedString(attachment: resizableAttachment),
                at: effectiveRange.location
            )
        }
        setAttributedString(mutableAttributedString)
    }
}
