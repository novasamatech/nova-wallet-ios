import UIKit

final class RadioSelectorView: UIView {
    var outerRadius: CGFloat = 10.0 {
        didSet {
            setNeedsDisplay()
        }
    }

    var outerColor: UIColor = R.color.colorAccent()! {
        didSet {
            if selected {
                setNeedsDisplay()
            }
        }
    }

    var innerRadius: CGFloat = 4.0 {
        didSet {
            if !selected {
                setNeedsDisplay()
            }
        }
    }

    var innerColor: UIColor = R.color.colorBlack()! {
        didSet {
            if selected {
                setNeedsDisplay()
            }
        }
    }

    var strokeColor: UIColor = R.color.colorWhite24()! {
        didSet {
            if !selected {
                setNeedsDisplay()
            }
        }
    }

    var strokeWidth: CGFloat = 1.0 {
        didSet {
            if !selected {
                setNeedsDisplay()
            }
        }
    }

    var selected: Bool = false {
        didSet {
            setNeedsDisplay()
        }
    }

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

        guard let context = UIGraphicsGetCurrentContext() else {
            return
        }

        let center = CGPoint(x: rect.midX, y: rect.midY)

        if selected {
            context.addArc(
                center: center,
                radius: outerRadius,
                startAngle: 0,
                endAngle: 2 * CGFloat.pi,
                clockwise: false
            )

            context.setFillColor(outerColor.cgColor)
            context.fillPath()

            context.addArc(
                center: center,
                radius: innerRadius,
                startAngle: 0,
                endAngle: 2 * CGFloat.pi,
                clockwise: false
            )

            context.setFillColor(innerColor.cgColor)
            context.fillPath()
        } else {
            context.addArc(
                center: center,
                radius: outerRadius - strokeWidth / 2.0,
                startAngle: 0,
                endAngle: 2 * CGFloat.pi,
                clockwise: false
            )

            context.setLineWidth(strokeWidth)
            context.setStrokeColor(strokeColor.cgColor)
            context.strokePath()
        }
    }
}
