import Foundation

final class OverlayBlurBackgroundView: BlurBackgroundView {
    let overlayView: TriangularedView = .create { view in
        view.shadowOpacity = 0
        view.fillColor = R.color.colorBlockBackground()!
    }

    override func configure() {
        super.configure()

        if let borderView = borderView {
            insertSubview(overlayView, belowSubview: borderView)
        } else {
            addSubview(overlayView)
        }
    }

    override func applyCornerProperties() {
        super.applyCornerProperties()

        overlayView.sideLength = sideLength
        overlayView.cornerCut = cornerCut
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        overlayView.frame = bounds
    }
}
