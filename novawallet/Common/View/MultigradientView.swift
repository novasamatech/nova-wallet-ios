import UIKit

class MultigradientView: UIView {
    var cornerRadius: CGFloat = 0.0 {
        didSet {
            setNeedsLayout()
        }
    }

    var colors: [UIColor] = [.white, .black] {
        didSet {
            applyColors()
        }
    }

    var startPoint = CGPoint(x: 0.0, y: 0.0) {
        didSet {
            applyStartPoint()
        }
    }

    var endPoint = CGPoint(x: 0.0, y: 1.0) {
        didSet {
            applyEndPoint()
        }
    }

    var locations: [Float]? {
        didSet {
            applyLocations()
        }
    }

    // MARK: Layer methods

    override class var layerClass: AnyClass {
        CAGradientLayer.self
    }

    // MARK: Initializer

    override init(frame: CGRect) {
        super.init(frame: frame)
        configure()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        configure()
    }

    override func prepareForInterfaceBuilder() {
        super.prepareForInterfaceBuilder()
        configure()
    }

    // MARK: Layout methods

    override func didMoveToWindow() {
        super.didMoveToWindow()

        if let window = self.window {
            layer.contentsScale = window.screen.scale
            layer.rasterizationScale = window.screen.scale
            setNeedsDisplay()
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        applyMask()
    }

    // MARK: Configuration methods

    func configure() {
        backgroundColor = UIColor.clear

        configureLayer()
    }

    func configureLayer() {
        if let layer = self.layer as? CAGradientLayer {
            layer.shouldRasterize = true
            applyLayerStyle()
        }
    }

    // MARK: Layer Style methods

    func applyLayerStyle() {
        applyColors()
        applyStartPoint()
        applyEndPoint()
        applyLocations()
    }

    private func applyColors() {
        if let layer = self.layer as? CAGradientLayer {
            layer.colors = colors.map(\.cgColor)
        }
    }

    private func applyStartPoint() {
        if let layer = self.layer as? CAGradientLayer {
            layer.startPoint = startPoint
        }
    }

    private func applyEndPoint() {
        if let layer = self.layer as? CAGradientLayer {
            layer.endPoint = endPoint
        }
    }

    private func applyLocations() {
        if let layer = self.layer as? CAGradientLayer {
            layer.locations = locations?.map { NSNumber(value: $0) }
        }
    }

    private func applyMask() {
        if let layer = self.layer as? CAGradientLayer {
            if cornerRadius > 0 {
                let path = CGMutablePath()
                path.addRoundedRect(
                    in: layer.bounds,
                    cornerWidth: cornerRadius,
                    cornerHeight: cornerRadius
                )

                let mask = CAShapeLayer()
                mask.frame = layer.bounds
                mask.path = path
                layer.mask = mask
            } else {
                layer.mask = nil
            }
        }
    }
}
