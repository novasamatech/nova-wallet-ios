import Foundation
import UIKit

class ShimmerLabel: UILabel {
    private enum Constants {
        static let gradientStartPoint = CGPoint(x: 0.0, y: 0.5)
        static let gradientEndPoint = CGPoint(x: 1.0, y: 0.5)
        static let animationDuration: TimeInterval = 1.0
    }

    private let topLabel = UILabel()
    private let gradientLayer = CAGradientLayer()

    private let animator = ShimmeringAnimator(duration: Constants.animationDuration)

    var isAnimating: Bool { !topLabel.isHidden }

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

    var runningColor: UIColor? {
        get {
            topLabel.textColor
        }

        set {
            topLabel.textColor = newValue
        }
    }

    var animatingColor: UIColor? = .white {
        didSet {
            if isAnimating {
                textColor = animatingColor
            }
        }
    }

    var normalColor: UIColor? = .white {
        didSet {
            if !isAnimating {
                textColor = normalColor
            }
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

    override var minimumScaleFactor: CGFloat {
        get {
            super.minimumScaleFactor
        }

        set {
            topLabel.minimumScaleFactor = newValue
            super.minimumScaleFactor = newValue
        }
    }

    override var allowsDefaultTighteningForTruncation: Bool {
        get {
            super.allowsDefaultTighteningForTruncation
        }

        set {
            topLabel.allowsDefaultTighteningForTruncation = newValue
            super.allowsDefaultTighteningForTruncation = newValue
        }
    }

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
        configure()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func configure() {
        gradientLayer.colors = [UIColor.clear.cgColor, UIColor.white.cgColor, UIColor.clear.cgColor]
        gradientLayer.startPoint = Constants.gradientStartPoint
        gradientLayer.endPoint = Constants.gradientEndPoint

        topLabel.layer.mask = gradientLayer
    }

    private func setupLayout() {
        addSubview(topLabel)

        topLabel.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    func startShimmering() {
        topLabel.isHidden = false
        textColor = animatingColor

        addAnimation()
    }

    func stopShimmering() {
        topLabel.isHidden = true
        textColor = normalColor

        stopAnimation()
    }

    func updateShimmeringIfActive() {
        guard isAnimating else {
            return
        }

        addAnimation()
    }

    private func addAnimation() {
        animator.stopAnimation(on: gradientLayer)
        animator.startAnimation(on: gradientLayer)
    }

    private func stopAnimation() {
        animator.stopAnimation(on: gradientLayer)
    }

    override public func layoutSubviews() {
        super.layoutSubviews()
        gradientLayer.frame = topLabel.frame

        if isAnimating {
            addAnimation()
        }
    }
}

extension ShimmerLabel {
    struct ShimmerStyle {
        let normal: UILabel.Style
        let animatingColor: UIColor
        let runningColor: UIColor

        static let regularSubheadlinePrimary = ShimmerStyle(
            normal: .regularSubhedlinePrimary,
            animatingColor: R.color.colorTextPrimary()!.withAlphaComponent(0.16),
            runningColor: R.color.colorTextPrimary()!
        )

        static let boldTitle2Primary = ShimmerStyle(
            normal: .boldTitle2Primary,
            animatingColor: R.color.colorTextPrimary()!.withAlphaComponent(0.4),
            runningColor: R.color.colorTextPrimary()!
        )

        static let regularSubheadlineSecondary = ShimmerStyle(
            normal: .regularSubhedlineSecondary,
            animatingColor: R.color.colorTextPrimary()!.withAlphaComponent(0.4),
            runningColor: R.color.colorTextPrimary()!
        )

        static let caption2Secondary = ShimmerStyle(
            normal: .caption2Secondary,
            animatingColor: R.color.colorTextPrimary()!.withAlphaComponent(0.4),
            runningColor: R.color.colorTextPrimary()!
        )

        static let footnoteSecondary = ShimmerStyle(
            normal: .footnoteSecondary,
            animatingColor: R.color.colorTextPrimary()!.withAlphaComponent(0.4),
            runningColor: R.color.colorTextPrimary()!
        )

        static let semiboldBodyPrimary = ShimmerStyle(
            normal: .semiboldBodyPrimary,
            animatingColor: R.color.colorTextPrimary()!.withAlphaComponent(0.4),
            runningColor: R.color.colorTextPrimary()!
        )

        static let semiboldBodySecondary = ShimmerStyle(
            normal: .semiboldBodySecondary,
            animatingColor: R.color.colorTextPrimary()!.withAlphaComponent(0.4),
            runningColor: R.color.colorTextPrimary()!
        )

        static let semiboldCaps2Secondary = ShimmerStyle(
            normal: .semiboldCaps2Secondary,
            animatingColor: R.color.colorTextPrimary()!.withAlphaComponent(0.4),
            runningColor: R.color.colorTextPrimary()!
        )

        static let semiboldFootnotePrimary = ShimmerStyle(
            normal: .semiboldFootnotePrimary,
            animatingColor: R.color.colorTextPrimary()!.withAlphaComponent(0.4),
            runningColor: R.color.colorTextPrimary()!
        )

        static let semiboldFootnotePositive = ShimmerStyle(
            normal: .semiboldFootnotePositive,
            animatingColor: R.color.colorTextPositive()!.withAlphaComponent(0.4),
            runningColor: R.color.colorTextPositive()!
        )

        static let semiboldCalloutPositive = ShimmerStyle(
            normal: .semiboldCalloutPositive,
            animatingColor: R.color.colorTextPositive()!.withAlphaComponent(0.4),
            runningColor: R.color.colorTextPositive()!
        )
    }

    func applyShimmer(style: ShimmerStyle) {
        normalColor = style.normal.textColor
        font = style.normal.font
        animatingColor = style.animatingColor
        runningColor = style.runningColor
    }
}

extension ShimmerLabel {
    func bind(viewModel: LoadableViewModelState<String>) {
        stopShimmering()

        switch viewModel {
        case .loading:
            text = nil
        case let .cached(value):
            text = value
            startShimmering()
        case let .loaded(value):
            text = value
        }
    }
}
