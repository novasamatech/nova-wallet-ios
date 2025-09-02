import UIKit
import UIKit_iOS

class DiscreteGradientSlider: UIControl {
    let thumbImageView = UIImageView()
    let trackBackgroundView: MultigradientView = .create { view in
        view.startPoint = CGPoint(x: 0.0, y: 0.5)
        view.endPoint = CGPoint(x: 1.0, y: 0.5)
    }

    let trackOverlayView: RoundedView = .create { view in
        view.applyCellBackgroundStyle()
    }

    var value: UInt = 0 {
        didSet {
            setNeedsLayout()
        }
    }

    var numberOfValues: UInt = 3 {
        didSet {
            reconfigureSteps()
            setNeedsLayout()
        }
    }

    var trackHeight: CGFloat = 10.0 {
        didSet {
            trackBackgroundView.cornerRadius = trackHeight / 2.0
            trackOverlayView.cornerRadius = trackHeight / 2.0

            invalidateIntrinsicContentSize()
            setNeedsLayout()
        }
    }

    var dotRadius: CGFloat = 3.0 {
        didSet {
            setNeedsLayout()
        }
    }

    var dotColor: UIColor = R.color.colorVotingSliderIndicatorInactive()! {
        didSet {
            updateDotsStyle(dots)
        }
    }

    var verticalSpacing: CGFloat = 5.0 {
        didSet {
            invalidateIntrinsicContentSize()
            setNeedsLayout()
        }
    }

    var sliderInset: CGFloat = 16 {
        didSet {
            setNeedsLayout()
        }
    }

    var dragTriggerOffset: CGFloat = 5.0

    var titleFont: UIFont? {
        didSet {
            updateTitlesStyle()

            invalidateIntrinsicContentSize()
            setNeedsLayout()
        }
    }

    var contentInsets: UIEdgeInsets = .zero {
        didSet {
            invalidateIntrinsicContentSize()
            setNeedsLayout()
        }
    }

    override var intrinsicContentSize: CGSize {
        let sliderHeight = max(thumbImageView.intrinsicContentSize.height, trackHeight)

        let labelsHeight = titleLabels.map(\.intrinsicContentSize.height).max() ?? 0

        let height = labelsHeight + verticalSpacing + sliderHeight + contentInsets.top + contentInsets.bottom
        return CGSize(width: UIView.noIntrinsicMetric, height: height)
    }

    var colors: [UIColor] {
        get {
            trackBackgroundView.colors
        }

        set {
            trackBackgroundView.colors = newValue

            updateTitlesStyle()
        }
    }

    var titles: [String] {
        get {
            titleLabels.map { $0.text ?? "" }
        }

        set {
            guard newValue.count == titleLabels.count else {
                return
            }

            zip(newValue, titleLabels).forEach { $0.1.text = $0.0 }

            invalidateIntrinsicContentSize()
            setNeedsLayout()
        }
    }

    private var dots: [RoundedView] = []
    private var titleLabels: [UILabel] = []

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = .clear

        configure()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func configure() {
        trackOverlayView.isUserInteractionEnabled = false
        trackBackgroundView.isUserInteractionEnabled = false

        trackBackgroundView.cornerRadius = trackHeight / 2.0
        trackOverlayView.cornerRadius = trackHeight / 2.0

        addSubview(trackBackgroundView)
        addSubview(trackOverlayView)
        addSubview(thumbImageView)

        reconfigureSteps()
    }

    private func reconfigureSteps() {
        if dots.count > numberOfValues {
            let dropCount = dots.count - Int(numberOfValues)

            let removingDots = Array(dots.suffix(dropCount))
            removingDots.forEach { $0.removeFromSuperview() }

            dots = dots.dropLast(dropCount)

            let removingTitles = Array(titleLabels.suffix(dropCount))
            removingTitles.forEach { $0.removeFromSuperview() }

            titleLabels = titleLabels.dropLast(dropCount)

        } else if dots.count < numberOfValues {
            let addCount = Int(numberOfValues) - dots.count

            let newDots: [RoundedView] = (0 ..< addCount).map { _ in
                let dotView = RoundedView()
                dotView.shadowOpacity = 0.0
                dotView.isUserInteractionEnabled = false
                return dotView
            }

            newDots.forEach { insertSubview($0, aboveSubview: trackOverlayView) }

            updateDotsStyle(newDots)

            dots.append(contentsOf: newDots)

            let newTitleLabels = (0 ..< addCount).map { _ in UILabel() }

            newTitleLabels.forEach { insertSubview($0, aboveSubview: trackOverlayView) }

            titleLabels.append(contentsOf: newTitleLabels)

            updateTitlesStyle()
        }
    }

    private func updateDotsStyle(_ dots: [RoundedView]) {
        dots.forEach { dot in
            dot.fillColor = dotColor
        }
    }

    private func updateTitlesStyle() {
        titleLabels.enumerated().forEach { index, label in
            if index < colors.count {
                label.textColor = colors[index]
            } else {
                label.textColor = colors.last
            }

            label.font = titleFont
        }
    }

    private func calculateStep() -> CGFloat {
        let availableWidth = bounds.width - contentInsets.left - contentInsets.right -
            2 * (sliderInset + dotRadius)

        if availableWidth > 0, numberOfValues > 1 {
            return availableWidth / CGFloat(numberOfValues - 1)
        } else {
            return 0
        }
    }

    private func stepPositionX(for value: UInt) -> CGFloat {
        let step = calculateStep()
        return contentInsets.left + sliderInset + dotRadius + CGFloat(value) * step
    }

    private func layoutDynamicViews() {
        let positionX = stepPositionX(for: value)

        let size = thumbImageView.intrinsicContentSize

        thumbImageView.frame = CGRect(
            x: positionX - size.width / 2.0,
            y: trackBackgroundView.frame.midY - size.height / 2.0,
            width: size.width,
            height: size.height
        )

        let overlaySize = CGSize(width: bounds.width - positionX, height: trackHeight)
        trackOverlayView.frame = CGRect(
            x: positionX,
            y: trackBackgroundView.frame.midY - overlaySize.height / 2.0,
            width: overlaySize.width,
            height: overlaySize.height
        )
    }

    private func layoutDots() {
        (0 ..< numberOfValues).forEach { value in
            let positionX = stepPositionX(for: value)

            let dotView = dots[Int(value)]
            dotView.frame = CGRect(
                x: positionX - dotRadius,
                y: trackBackgroundView.frame.midY - dotRadius,
                width: 2 * dotRadius,
                height: 2 * dotRadius
            )

            dotView.cornerRadius = dotRadius
        }
    }

    private func layoutTitleLabels() {
        (0 ..< numberOfValues).forEach { value in
            let positionX = stepPositionX(for: value)

            let titleLabel = titleLabels[Int(value)]
            let size = titleLabel.intrinsicContentSize

            titleLabel.frame = CGRect(
                x: positionX - size.width / 2.0,
                y: contentInsets.top,
                width: size.width,
                height: size.height
            )
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        let sliderHeight = max(trackHeight, thumbImageView.intrinsicContentSize.height)

        trackBackgroundView.frame = CGRect(
            x: bounds.minX + contentInsets.left,
            y: bounds.maxY - contentInsets.bottom - sliderHeight / 2.0 - trackHeight / 2.0,
            width: bounds.width - contentInsets.left - contentInsets.right,
            height: trackHeight
        )

        layoutDynamicViews()
        layoutDots()
        layoutTitleLabels()
    }

    private func updateValue(for location: CGFloat) {
        let step = calculateStep()

        guard step > 0 else {
            return
        }

        let diff = round((location - stepPositionX(for: 0)) / step)

        let oldValue = value
        value = min(numberOfValues - 1, UInt(max(0, Int(diff))))

        if oldValue != value {
            sendActions(for: .valueChanged)
        }
    }

    override func beginTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
        super.beginTracking(touch, with: event)

        let locationX = touch.location(in: self).x

        updateValue(for: locationX)

        return true
    }

    override func continueTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
        super.beginTracking(touch, with: event)

        let locationX = touch.location(in: self).x

        updateValue(for: locationX)

        return true
    }
}
