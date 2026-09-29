import UIKit

final class SubtensorSparklineView: UIView {
    private let lineLayer: CAShapeLayer = {
        let layer = CAShapeLayer()
        layer.fillColor = UIColor.clear.cgColor
        layer.lineWidth = Constants.lineWidth
        layer.lineJoin = .round
        layer.lineCap = .round
        return layer
    }()

    private var values: [Double] = []

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = .clear
        isUserInteractionEnabled = false
        layer.addSublayer(lineLayer)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        updatePath()
    }

    func bind(values: [Double], isRising: Bool) {
        self.values = values.filter(\.isFinite)

        let color = isRising ? R.color.colorTextPositive() : R.color.colorTextNegative()
        lineLayer.strokeColor = color?.cgColor

        updatePath()
    }

    func clear() {
        values = []

        updatePath()
    }
}

private extension SubtensorSparklineView {
    func updatePath() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)

        lineLayer.frame = bounds
        lineLayer.path = createPath()?.cgPath

        CATransaction.commit()
    }

    func createPath() -> UIBezierPath? {
        guard
            values.count > 1,
            let minValue = values.min(),
            let maxValue = values.max(),
            bounds.width > 0,
            bounds.height > 0 else {
            return nil
        }

        let inset = Constants.lineWidth / 2
        let drawingRect = bounds.insetBy(dx: inset, dy: inset)
        let range = maxValue - minValue
        let stepX = drawingRect.width / CGFloat(values.count - 1)

        let path = UIBezierPath()

        for (index, value) in values.enumerated() {
            let ratio = range > 0 ? (value - minValue) / range : Constants.flatRatio

            let point = CGPoint(
                x: drawingRect.minX + CGFloat(index) * stepX,
                y: drawingRect.maxY - CGFloat(ratio) * drawingRect.height
            )

            if index == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }

        return path
    }

    enum Constants {
        static let lineWidth: CGFloat = 1.5
        static let flatRatio: Double = 0.5
    }
}
