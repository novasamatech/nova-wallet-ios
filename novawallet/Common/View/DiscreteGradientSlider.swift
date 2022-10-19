import UIKit
import SoraUI

class DiscreteGradientSlider: UIControl {
    let thumbImageView: UIImageView = UIImageView()
    let trackBackgroundView: MultigradientView = MultigradientView()
    let trackOverlayView: RoundedView = RoundedView()

    private(set) var value: UInt = 0
    private(set) var numberOfValues: UInt = 3

    var trackHeight: CGFloat = 8.0 {
        didSet {
            setNeedsLayout()
        }
    }

    var contentInsets: UIEdgeInsets = UIEdgeInsets(top: 16.0, left: 0.0, bottom: 16.0, right: 0.0) {
        didSet {
            invalidateIntrinsicContentSize()
            setNeedsLayout()
        }
    }

    override var intrinsicContentSize: CGSize {
        let contentHeight = max(thumbImageView.intrinsicContentSize.height, trackHeight)
        let height = contentHeight + contentInsets.top + contentInsets.bottom
        return CGSize(width: UIView.noIntrinsicMetric, height: height)
    }

    var colors: [UIColor] {
        trackBackgroundView.colors
    }

    private var dots: [RoundedView] = []

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = .clear

        configure()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func configure() {
        addSubview(trackBackgroundView)
        addSubview(trackOverlayView)
        addSubview(thumbImageView)
    }

    private func updateThumbPosition() {
        guard numberOfValues > 1 else {
            return
        }

        let step = bounds.height / CGFloat(numberOfValues - 1)
        let positionX = CGFloat(value) * step

        let size = thumbImageView.intrinsicContentSize

        thumbImageView.frame = CGRect(
            x: positionX - size.width / 2.0,
            y: bounds.midY - size.height / 2.0,
            width: size.width,
            height: size.height
        )
    }

    override func layoutSubviews() {
        super.layoutSubviews()
    }
}
