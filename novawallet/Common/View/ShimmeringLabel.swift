import Foundation
import UIKit

class ShimmerLabel: UILabel {
    private let topLabel = UILabel()
    private let gradientLayer = CAGradientLayer()

    override var text: String? {
        get {
            super.text
        }

        set {
            topLabel.text = newValue
            super.text = newValue
        }
    }

    override var font: UIFont! {
        get {
            super.font
        }

        set {
            topLabel.font = newValue
            super.font = newValue
        }
    }

    var shimmerColor: UIColor = .white {
        didSet {
            topLabel.textColor = shimmerColor
        }
    }

    override var textColor: UIColor! {
        get {
            super.textColor
        }

        set {
            super.textColor = newValue
        }
    }

    override var textAlignment: NSTextAlignment {
        get {
            super.textAlignment
        }

        set {
            topLabel.textAlignment = newValue
            super.textAlignment = newValue
        }
    }

    override var lineBreakMode: NSLineBreakMode {
        get {
            super.lineBreakMode
        }

        set {
            topLabel.lineBreakMode = newValue
            super.lineBreakMode = newValue
        }
    }


    @available(iOS 6.0, *)
    override var attributedText: NSAttributedString? {
        get {
            super.attributedText
        }

        set {
            topLabel.attributedText = newValue
            super.attributedText = newValue
        }
    }

    override var highlightedTextColor: UIColor? {
        get {
            super.highlightedTextColor
        }

        set {
            topLabel.highlightedTextColor = newValue
            super.highlightedTextColor = newValue
        }
    }

    override var isHighlighted: Bool {
        get {
            super.isHighlighted
        }

        set {
            topLabel.isHighlighted = newValue
            super.isHighlighted = newValue
        }
    }


    override var isEnabled: Bool {
        get {
            super.isEnabled
        }

        set {
            topLabel.isEnabled = newValue
            super.isEnabled = newValue
        }
    }

    override var numberOfLines: Int {
        get {
            super.numberOfLines
        }

        set {
            topLabel.numberOfLines = newValue
            super.numberOfLines = newValue
        }
    }


    override var adjustsFontSizeToFitWidth: Bool {
        get {
            super.adjustsFontSizeToFitWidth
        }

        set {
            topLabel.adjustsFontSizeToFitWidth = newValue
            super.adjustsFontSizeToFitWidth = newValue
        }
    }

    override var baselineAdjustment: UIBaselineAdjustment {
        get {
            super.baselineAdjustment
        }

        set {
            topLabel.baselineAdjustment = newValue
            super.baselineAdjustment = newValue
        }
    }

    @available(iOS 6.0, *)
    override var minimumScaleFactor: CGFloat {
        get {
            super.minimumScaleFactor
        }

        set {
            topLabel.minimumScaleFactor = newValue
            super.minimumScaleFactor = newValue
        }
    }

    @available(iOS 9.0, *)
    override var allowsDefaultTighteningForTruncation: Bool {
        get {
            super.allowsDefaultTighteningForTruncation
        }

        set {
            topLabel.allowsDefaultTighteningForTruncation = newValue
            super.allowsDefaultTighteningForTruncation = newValue
        }
    }


    @available(iOS 6.0, *)
    override var preferredMaxLayoutWidth: CGFloat {
        get {
            super.preferredMaxLayoutWidth
        }

        set {
            topLabel.preferredMaxLayoutWidth = newValue
            super.preferredMaxLayoutWidth = newValue
        }
    }

    convenience init() {
        self.init(frame: .zero)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupLayout()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func configure() {
        gradientLayer.colors = [UIColor.white.cgColor, UIColor.clear.cgColor, UIColor.white.cgColor]
        gradientLayer.locations = [0, 0.5, 1]

        topLabel.textColor = shimmerColor
        topLabel.layer.mask = gradientLayer
    }

    private func setupLayout() {
        addSubview(topLabel)

        topLabel.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    func start() {

    }

    private func addAnimation() {
        gradientLayer.removeAllAnimations()
        let animation = CABasicAnimation(keyPath: "transform.translation.x")
        animation.fromValue = -self.frame.size.width
        animation.toValue = self.frame.size.width
        animation.duration = 15.0
        animation.repeatCount = .infinity
        gradientLayer.add(animation, forKey: "animationKey")
    }

    private func stopAnimation() {
        gradientLayer.removeAllAnimations()
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        gradientLayer.frame = topLabel.frame

        
    }
}
