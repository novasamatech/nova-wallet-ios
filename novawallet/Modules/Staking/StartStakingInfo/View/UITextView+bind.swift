import UIKit
import Foundation

extension UITextView {
    func bind(url: URL, urlText: String, in text: String) {
        let font = UIFont.regularCallout
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        let attributedString = NSMutableAttributedString(
            string: text,
            attributes: [.foregroundColor: R.color.colorTextTertiary()!,
                         .font: font,
                         .paragraphStyle: paragraphStyle]
        )
        if let range = text.range(of: urlText) {
            let imageSize = CGSize(width: 20, height: 20)
            let nsRange = NSRange(range, in: text)
            attributedString.addAttribute(.link, value: url, range: nsRange)
            let imageAttachment = NSTextAttachment()
            imageAttachment.image = R.image.iconLinkChevron()!.tinted(with: R.color.colorTextSecondary()!)
            let centerImageY = 2 * font.descender - imageSize.height / 2 + font.capHeight
            imageAttachment.bounds = .init(origin: .init(x: 0, y: centerImageY), size: imageSize)
            attributedString.append(.init(attachment: imageAttachment))
        }
        attributedText = attributedString
    }
}
