import UIKit
import UIKit_iOS

@IBDesignable
open class BlockBackgroundView: UIView {
    private(set) var contentView: TriangularedView?
    private(set) var overlayView: TriangularedView?
    override public init(frame: CGRect) {
        super.init(frame: frame)

        configure()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)

        configure()
    }

    var sideLength: CGFloat = 10.0 {
        didSet {
            contentView?.sideLength = sideLength
            overlayView?.sideLength = sideLength
        }
    }

    var cornerCut: UIRectCorner = .allCorners {
        didSet {
            contentView?.cornerCut = cornerCut
            overlayView?.cornerCut = cornerCut
        }
    }

    open func configure() {
        backgroundColor = .clear

        addBlurView()
        addOverlayView()
    }

    private func addOverlayView() {
        if overlayView == nil {
            let overlayView = TriangularedView()
            overlayView.cornerCut = cornerCut
            overlayView.sideLength = sideLength
            overlayView.shadowOpacity = 0.0
            overlayView.fillColor = .clear
            overlayView.highlightedFillColor = .clear
            addSubview(overlayView)

            self.overlayView = overlayView
        }
    }

    private func addBlurView() {
        if contentView == nil {
            let blurMaskView = TriangularedView()
            blurMaskView.cornerCut = cornerCut
            blurMaskView.shadowOpacity = 0.0
            blurMaskView.fillColor = R.color.colorBlockBackground()!

            insertSubview(blurMaskView, at: 0)

            contentView = blurMaskView
        }
    }

    override open func layoutSubviews() {
        super.layoutSubviews()

        contentView?.frame = CGRect(origin: .zero, size: bounds.size)
        overlayView?.frame = bounds
    }
}

extension BlockBackgroundView: Highlightable {
    public func set(highlighted: Bool, animated: Bool) {
        overlayView?.set(highlighted: highlighted, animated: animated)
    }
}
