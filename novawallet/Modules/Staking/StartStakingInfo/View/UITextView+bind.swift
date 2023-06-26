import UIKit
import Foundation

extension UITextView {
    func bind(url: URL, urlText: String, in text: String) {
        let attributedString = NSMutableAttributedString(
            string: text,
            attributes: [.foregroundColor: R.color.colorTextTertiary()!,
                         .font: UIFont.regularCallout]
        )
        if let range = text.range(of: urlText) {
            let nsRange = NSRange(range, in: text)
            attributedString.addAttribute(.link, value: url, range: nsRange)
            let imageAttachment = NSTextAttachment()
            let mid = UIFont.regularCallout.descender + UIFont.regularCallout.capHeight
            imageAttachment.image = R.image.iconLinkChevron()!.tinted(with: R.color.colorTextTertiary()!)
            let centerImageY = UIFont.regularCallout.descender - 10 + mid
            imageAttachment.bounds = .init(origin: .init(x: 0, y: centerImageY), size: .init(width: 20, height: 20))
            attributedString.append(.init(attachment: imageAttachment))
        }
        attributedText = attributedString
    }
}
