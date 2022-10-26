import UIKit

final class DotsView: UIView {
    struct Model {
        let isFinite: Bool
    }

    var points: [Model] = [] {
        didSet {
            invalidateIntrinsicContentSize()
            setNeedsDisplay()
        }
    }

    private var style: Style = .defaultStyle

    var contentInsets = UIEdgeInsets(top: 1, left: 1, bottom: 1, right: 1)

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

    override var intrinsicContentSize: CGSize {
        let height = CGFloat(points.count) * (2 * style.dotRadius + style.pointSpacing) + style.lastExtraSpace

        return CGSize(
            width: 2 * style.dotRadius + contentInsets.left + contentInsets.right,
            height: height + contentInsets.top + contentInsets.bottom
        )
    }

    private func drawDots() {
        guard let context = UIGraphicsGetCurrentContext() else {
            return
        }

        setup(context: context)
        let dotX = bounds.midX

        for index in 0 ..< points.count {
            let dotY = bounds.minY + contentInsets.top + CGFloat(index) * (2 * style.dotRadius + style.pointSpacing) +
                style.dotRadius
            let firstDot = createCircle(with: .init(x: dotX, y: dotY))

            if index == points.count - 1 {
                firstDot.stroke()
                firstDot.fill()

                if !points[index].isFinite {
                    let dottedLinePath = UIBezierPath()
                    let lineStart = dotY + style.dotRadius + style.lineSpacing
                    let lineEnd = dotY + style.dotRadius + style.pointSpacing + style.lastExtraSpace
                    dottedLinePath.move(to: .init(x: dotX, y: lineStart))
                    dottedLinePath.setLineDash(style.pattern, count: style.pattern.count, phase: 0)
                    dottedLinePath.addLine(to: .init(x: dotX, y: lineEnd))

                    context.setStrokeColor(style.dashedColor.cgColor)
                    dottedLinePath.stroke()
                }
            } else {
                let lineStart = dotY + style.dotRadius + style.lineSpacing
                let lineEnd = dotY + style.dotRadius + style.pointSpacing - style.lineSpacing
                firstDot.move(to: .init(x: dotX, y: lineStart))
                firstDot.addLine(to: .init(x: dotX, y: lineEnd))
                firstDot.stroke()
                firstDot.fill()
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
        context.setStrokeColor(style.connectingColor.cgColor)
        context.setFillColor(style.connectingColor.cgColor)
        context.setLineWidth(style.lineWidth)
    }
}

extension DotsView {
    struct Style {
        let lineWidth: CGFloat
        let connectingColor: UIColor
        let dashedColor: UIColor
        let dotRadius: CGFloat
        let pointSpacing: CGFloat
        let lineSpacing: CGFloat
        let pattern: [CGFloat]
        let lastExtraSpace: CGFloat
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
        connectingColor: R.color.colorNovaBlue()!,
        dashedColor: R.color.colorWhite24()!,
        dotRadius: 6,
        pointSpacing: 36,
        lineSpacing: 6,
        pattern: [2, 3],
        lastExtraSpace: 4
    )
}
