import Foundation
import UIKit

extension String {
    func estimateMaxFontSize(
        fittingWidthOf size: CGSize,
        fontFamily: String,
        minSize: CGFloat,
        maxSize: CGFloat
    ) -> CGFloat {
        var currentFontSize = maxSize

        while currentFontSize >= minSize {
            guard let font = UIFont(name: fontFamily, size: currentFontSize) else {
                return currentFontSize
            }

            let estimatedWidth = estimateWidth(for: font, height: size.height)

            if estimatedWidth <= size.width {
                return currentFontSize
            }

            currentFontSize -= 1.0
        }

        return currentFontSize
    }

    func estimateWidth(for font: UIFont, height: CGFloat) -> CGFloat {
        (self as NSString).boundingRect(
            with: CGSize(
                width: CGFloat.greatestFiniteMagnitude,
                height: height
            ),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: font],
            context: nil
        ).width
    }

    func estimateHeight(for font: UIFont, width: CGFloat) -> CGFloat {
        (self as NSString).boundingRect(
            with: CGSize(width: width, height: CGFloat.greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: font],
            context: nil
        ).height
    }
}
