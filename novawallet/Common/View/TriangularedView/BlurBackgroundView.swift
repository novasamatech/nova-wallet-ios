import UIKit
import UIKit_iOS

open class BlurBackgroundView: UIView {
    private(set) var blurView: UIVisualEffectView?
    private(set) var blurMaskView: TriangularedView?
    private(set) var borderView: BorderedContainerView?

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
            applyCornerProperties()
        }
    }

    var cornerCut: UIRectCorner = .allCorners {
        didSet {
            applyCornerProperties()
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

    var borderType: BorderType {
        get {
            borderView?.borderType ?? []
        }

        set {
            borderView?.borderType = newValue
        }
    }

    var blurStyle: UIBlurEffect = .init(style: .dark) {
        didSet {
            blurView?.effect = blurStyle
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
        let blurView = UIVisualEffectView(effect: blurStyle)
        insertSubview(blurView, at: 0)

        self.blurView = blurView

        let blurMaskView = TriangularedView()
        blurMaskView.cornerCut = cornerCut
        blurMaskView.shadowOpacity = 0.0
        blurMaskView.fillColor = .black

        blurView.mask = blurMaskView

        self.blurMaskView = blurMaskView
    }

    func applyCornerProperties() {
        blurMaskView?.sideLength = sideLength
        blurMaskView?.cornerCut = cornerCut
    }

    override open func layoutSubviews() {
        super.layoutSubviews()

        let yOffset = borderType.contains(.top) ? borderWidth : 0
        var heightOffset: CGFloat = 0

        if borderType.contains(.top) {
            heightOffset += borderWidth
        }

        if borderType.contains(.bottom) {
            heightOffset += borderWidth
        }

        let size = CGSize(width: bounds.width, height: bounds.height - heightOffset)
        let origin = CGPoint(x: 0.0, y: yOffset)
        blurMaskView?.frame = CGRect(origin: origin, size: size)
        blurView?.frame = bounds
        borderView?.frame = bounds
    }
}
