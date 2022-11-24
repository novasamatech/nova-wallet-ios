import UIKit
import SoraUI

open class BlurBackgroundView: UIView {
    private var blurView: UIVisualEffectView?
    private var blurMaskView: TriangularedView?
    private var borderView: BorderedContainerView?

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
            blurMaskView?.sideLength = sideLength
        }
    }

    var cornerCut: UIRectCorner = .allCorners {
        didSet {
            blurMaskView?.cornerCut = cornerCut
        }
    }

    var borderWidth: CGFloat {
        get {
            borderView?.strokeWidth ?? 0
        }

        set {
            borderView?.strokeWidth = newValue

            setNeedsLayout()
        }
    }

    var borderColor: UIColor {
        get {
            borderView?.strokeColor ?? .black
        }

        set {
            borderView?.strokeColor = newValue
        }
    }

    open func configure() {
        backgroundColor = .clear

        addBorderView()
        addBlurView()
    }

    private func removeBlurView() {
        blurView?.removeFromSuperview()
        blurView = nil
        blurMaskView = nil
    }

    private func addBorderView() {
        let borderView = BorderedContainerView()
        borderView.borderType = .bottom
        borderView.strokeWidth = 0.5
        borderView.strokeColor = R.color.colorNavigationDivider()!
        addSubview(borderView)

        self.borderView = borderView
    }

    private func addBlurView() {
        let blur = UIBlurEffect(style: .dark)
        let blurView = UIVisualEffectView(effect: blur)
        insertSubview(blurView, at: 0)

        self.blurView = blurView

        let blurMaskView = TriangularedView()
        blurMaskView.cornerCut = cornerCut
        blurMaskView.shadowOpacity = 0.0
        blurMaskView.fillColor = .black

        blurView.mask = blurMaskView

        self.blurMaskView = blurMaskView
    }

    override open func layoutSubviews() {
        super.layoutSubviews()

        let size = CGSize(width: bounds.width, height: bounds.height - borderWidth)
        blurMaskView?.frame = CGRect(origin: .zero, size: size)
        blurView?.frame = bounds
        borderView?.frame = bounds
    }
}
