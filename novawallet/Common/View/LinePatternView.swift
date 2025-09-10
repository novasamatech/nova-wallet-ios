import Foundation
import UIKit
import UIKit_iOS

final class LinePatternView: UIView {
    var style: Style = .defaultStyle {
        didSet {
            setNeedsDisplay()
        }
    }

    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else {
            return
        }

        context.setLineWidth(style.lineWidth)
        context.setStrokeColor(style.color.cgColor)

        if let pattern = style.pattern {
            context.setLineDash(phase: pattern.phase, lengths: pattern.segments)
        }

        context.move(to: CGPoint(x: rect.midX, y: 0))
        context.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        context.drawPath(using: .stroke)
    }
}

extension LinePatternView {
    struct Pattern {
        let segments: [CGFloat]
        let phase: CGFloat
    }

    struct Style {
        let color: UIColor
        let lineWidth: CGFloat
        let pattern: Pattern?

        static var defaultStyle: Style {
            Style(
                color: R.color.colorIconSecondary()!,
                lineWidth: 1,
                pattern: LinePatternView.Pattern(
                    segments: [2, 3],
                    phase: 0
                )
            )
        }
    }
}
