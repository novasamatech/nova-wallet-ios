import UIKit

final class DotsView: UIView {
    struct Model {
        let view: BaselinedView
        let isFinite: Bool
    }

    var points: [Model] = []
    private var style: Style = .defaultStyle

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = .clear
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ rect: CGRect) {
        super.draw(rect)
        drawDots()
    }

    private func drawDots() {
        guard let context = UIGraphicsGetCurrentContext(),
              let superview = superview else {
            return
        }
        setup(context: context)
        let dotX = frame.midX

        for index in 0 ..< points.count {
            let dotY = points[index].view.firstBaseline.frame(in: superview).midY
            let firstDot = createCircle(with: .init(x: dotX, y: dotY))
            firstDot.move(to: .init(x: dotX, y: dotY + style.dotRadius + style.space))

            let nextDotY: CGFloat
            if index == points.count - 1 {
                firstDot.stroke()
                firstDot.fill()

                guard !points[index].isFinite else {
                    continue
                }
                let dottedLinePath = UIBezierPath()
                nextDotY = frame.maxY
                dottedLinePath.setLineDash(style.pattern, count: style.pattern.count, phase: 0)
                dottedLinePath.addLine(to: .init(x: dotX, y: nextDotY - style.dotRadius - style.space))
                dottedLinePath.stroke()
                dottedLinePath.fill()
            } else {
                nextDotY = points[index + 1].view.firstBaseline.frame(in: superview).midY
                firstDot.addLine(to: .init(x: dotX, y: nextDotY - style.dotRadius - style.space))
                firstDot.stroke()
                firstDot.fill()

                let secondDot = createCircle(with: .init(x: dotX, y: nextDotY))
                secondDot.stroke()
                secondDot.fill()
            }
        }
    }

    private func createCircle(with center: CGPoint) -> UIBezierPath {
        UIBezierPath(
            arcCenter: center,
            radius: style.dotRadius,
            startAngle: 0,
            endAngle: 2 * .pi,
            clockwise: true
        )
    }

    private func setup(context: CGContext) {
        context.setStrokeColor(style.color.cgColor)
        context.setFillColor(style.color.cgColor)
        context.setLineWidth(style.lineWidth)
    }
}

extension DotsView {
    struct Style {
        let lineWidth: CGFloat
        let color: UIColor
        let dotRadius: CGFloat
        let space: CGFloat
        let pattern: [CGFloat]
    }

    func apply(style: Style) {
        self.style = style
        invalidateIntrinsicContentSize()
        setNeedsDisplay()
    }
}

extension DotsView.Style {
    static let defaultStyle = DotsView.Style(
        lineWidth: 1,
        color: R.color.colorNovaBlue()!,
        dotRadius: 6,
        space: 6,
        pattern: [2, 3]
    )
}
