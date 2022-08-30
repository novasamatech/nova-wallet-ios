import UIKit

protocol ComfortTouchAreaControl: UIControl {}

extension ComfortTouchAreaControl {
    var minimumHitArea: CGSize { .init(width: 44, height: 44) }

    func point(inside point: CGPoint, with _: UIEvent?) -> Bool {
        let size = bounds.size
        let extendedWidth = max(minimumHitArea.width - size.width, 0)
        let extendedHeight = max(minimumHitArea.height - size.height, 0)
        let extendedFrame = bounds.insetBy(dx: -extendedWidth / 2, dy: -extendedHeight / 2)
        return extendedFrame.contains(point)
    }
}
