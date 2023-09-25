import UIKit

struct MarkupAttributedText {
    static let readMoreThreshold = 180

    let originalString: String
    let attributedString: NSAttributedString
    let preferredSize: CGSize
    let isFull: Bool
}
