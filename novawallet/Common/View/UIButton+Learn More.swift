import Foundation
import UIKit

extension UIButton {
    typealias Style = UILabel.Style

    func bindLearnMore(
        learnMoreText: String,
        in text: String? = nil,
        style: Style,
        showsChevron: Bool = true,
        for state: UIControl.State = .normal
    ) {
        let text = text ?? learnMoreText

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center

        let attributedString = NSMutableAttributedString(
            string: text,
            attributes: [
                .font: style.font,
                .paragraphStyle: paragraphStyle,
                .foregroundColor: style.textColor
            ]
        )

        if let range = text.range(of: learnMoreText) {
            let nsRange = NSRange(range, in: text)
            var nsRangeLength = nsRange.length

            if showsChevron {
                let attachment = createChevronAttachment(font: style.font)
                attributedString.append(attachment)
                nsRangeLength += 1
            }

            attributedString.addAttribute(
                .foregroundColor,
                value: R.color.colorButtonTextAccent(),
                range: NSRange(location: nsRange.location, length: nsRangeLength)
            )
        }

        setAttributedTitle(attributedString, for: state)
    }

    private func createChevronAttachment(font: UIFont) -> NSAttributedString {
        let size = CGSize(width: font.lineHeight, height: font.lineHeight)
        let imageAttachment = NSTextAttachment()
        imageAttachment.image = R.image.iconLinkChevron()

        let centerImageY = 2 * font.descender - size.height / 2 + font.capHeight
        imageAttachment.bounds = CGRect(origin: .init(x: 0, y: centerImageY), size: size)

        return NSAttributedString(attachment: imageAttachment)
    }
}
