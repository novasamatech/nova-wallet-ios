import UIKit

protocol AssetListStyleSwitcherAnimationDelegate: AnyObject {
    func didStartAnimating()
    func didEndAnimating()
}

class AssetListStyleSwitcherView: UIView {
    var locale = Locale.current {
        didSet {
            setupLocalizations()
        }
    }

    weak var delegate: AssetListStyleSwitcherAnimationDelegate?

    private var state: State = .tokens

    private let label: UILabel = .create { view in
        view.apply(style: .title3Primary)
        view.textAlignment = .left
    }

    private let indicatorContainer: UIView = .create { view in
        view.backgroundColor = .clear
    }

    private let labelContainer: UIView = .create { view in
        view.clipsToBounds = true
    }

    private let squareLayer = CAShapeLayer()
    private let circleLayer = CAShapeLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupView()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setup(with state: State) {
        guard state != self.state else {
            return
        }

        self.state = state

        setupIndicatorLayers(with: state)
        setupLocalizations()
    }

    func handleTap() {
        state.toggle()

        switch state {
        case .networks:
            animateToNetworks()
        case .tokens:
            animateToTokens()
        }
    }
}

// MARK: State

extension AssetListStyleSwitcherView {
    enum State {
        case networks
        case tokens

        mutating func toggle() {
            switch self {
            case .networks: self = .tokens
            case .tokens: self = .networks
            }
        }

        init(using assetListStyle: AssetListGroupsStyle) {
            switch assetListStyle {
            case .networks:
                self = .networks
            case .tokens:
                self = .tokens
            }
        }
    }
}

// MARK: Private

private extension AssetListStyleSwitcherView {
    func setupLocalizations() {
        switch state {
        case .networks:
            label.text = R.string(preferredLanguages: locale.rLanguages).localizable.commonNetworks()
        case .tokens:
            label.text = R.string(preferredLanguages: locale.rLanguages).localizable.commonTokens()
        }
    }

    func setupView() {
        setupSubviews()
        setupConstraints()
        setupIndicatorLayers(with: state)
    }

    func setupSubviews() {
        addSubview(indicatorContainer)
        addSubview(labelContainer)
        labelContainer.addSubview(label)
    }

    func setupConstraints() {
        indicatorContainer.snp.makeConstraints { make in
            make.leading.top.bottom.equalToSuperview()
            make.centerY.equalToSuperview()
            make.width.equalTo(Constants.indicatorContainerWidth)
            make.height.equalTo(Constants.indicatorContainerHeight)
        }
        labelContainer.snp.makeConstraints { make in
            make.leading.equalTo(indicatorContainer.snp.trailing).offset(8)
            make.trailing.equalToSuperview()
            make.centerY.equalToSuperview()
            make.height.equalTo(Constants.labelContainerHeight)
            make.width.equalTo(Constants.labelContainerWidth)
        }
        label.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    func setupIndicatorLayers(with state: State) {
        setupSquareLayer(selected: state == .networks)
        setupCircleLayer(selected: state == .tokens)
    }

    func setupSquareLayer(selected: Bool) {
        let squarePath = UIBezierPath(
            rect: CGRect(
                x: 0,
                y: 0,
                width: Constants.squareSize,
                height: Constants.squareSize
            )
        )
        squareLayer.path = squarePath.cgPath
        squareLayer.fillColor = selected
            ? R.color.colorIconPrimary()!.cgColor
            : R.color.colorIconInactive()!.cgColor
        squareLayer.position = CGPoint(x: 8, y: 4)

        squareLayer.removeFromSuperlayer()

        indicatorContainer.layer.addSublayer(squareLayer)
    }

    func setupCircleLayer(selected: Bool) {
        let circlePath = UIBezierPath(
            arcCenter: CGPoint(x: Constants.circleSize / 2, y: Constants.circleSize / 2),
            radius: Constants.circleSize / 2,
            startAngle: 0,
            endAngle: .pi * 2,
            clockwise: true
        )
        circleLayer.path = circlePath.cgPath
        circleLayer.fillColor = selected
            ? Constants.indicatorActiveColor
            : Constants.indicatorInactiveColor
        circleLayer.position = CGPoint(x: 8, y: 16)

        circleLayer.removeFromSuperlayer()

        indicatorContainer.layer.addSublayer(circleLayer)
    }
}

// MARK: Animation

private extension AssetListStyleSwitcherView {
    func animateToTokens() {
        animateLabels(
            newText: R.string(preferredLanguages: locale.rLanguages).localizable.commonTokens(),
            direction: .top
        )
        animateIndicators(
            squareColor: Constants.indicatorInactiveColor,
            circleColor: Constants.indicatorActiveColor
        )
    }

    func animateToNetworks() {
        animateLabels(
            newText: R.string(preferredLanguages: locale.rLanguages).localizable.commonNetworks(),
            direction: .bottom
        )
        animateIndicators(
            squareColor: Constants.indicatorActiveColor,
            circleColor: Constants.indicatorInactiveColor
        )
    }

    func animateLabels(
        newText: String,
        direction: AnimationDirection
    ) {
        let newLabel = UILabel()
        newLabel.text = newText
        newLabel.textAlignment = label.textAlignment
        newLabel.apply(style: .title3Primary)

        labelContainer.addSubview(newLabel)

        newLabel.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        layoutIfNeeded()

        let currentPosition = label.layer.position.y
        let initialOffset = Constants.rollDistance * -direction.yOffset

        newLabel.layer.position.y = currentPosition + initialOffset

        let currentSpring = createSpringAnimation(
            fromValue: currentPosition,
            toValue: currentPosition + (Constants.rollDistance * direction.yOffset),
            opaque: true,
            direction: direction
        )
        let newSpring = createSpringAnimation(
            fromValue: newLabel.layer.position.y,
            toValue: currentPosition,
            opaque: false,
            direction: direction
        )

        delegate?.didStartAnimating()

        CATransaction.begin()
        CATransaction.setCompletionBlock { [weak self] in
            self?.label.text = newText
            self?.label.layer.position.y = currentPosition
            self?.label.layer.opacity = 1.0

            self?.label.layer.removeAllAnimations()
            newLabel.removeFromSuperview()

            self?.delegate?.didEndAnimating()
        }

        label.layer.add(
            currentSpring,
            forKey: "rollOut"
        )
        newLabel.layer.add(
            newSpring,
            forKey: "rollIn"
        )
        CATransaction.commit()
    }

    func createSpringAnimation(
        fromValue: CGFloat?,
        toValue: CGFloat?,
        opaque: Bool,
        direction: AnimationDirection
    ) -> CAAnimationGroup {
        guard let fromValue = fromValue else { return CAAnimationGroup() }

        let anticipation = CABasicAnimation(keyPath: "position.y")
        anticipation.fromValue = fromValue
        anticipation.toValue = fromValue + (Constants.anticipationDistance * (-direction.yOffset))
        anticipation.duration = Constants.animationDuration * Constants.anticipationDurationRatio
        anticipation.timingFunction = CAMediaTimingFunction(name: .easeOut)

        let opacity = CABasicAnimation(keyPath: "opacity")
        opacity.fromValue = opaque ? 1.0 : 0.0
        opacity.toValue = opaque ? 0.0 : 1.0
        opacity.duration = Constants.animationDuration * (1 - Constants.anticipationDurationRatio)
        opacity.beginTime = anticipation.duration
        opacity.timingFunction = CAMediaTimingFunction(name: .easeOut)
        opacity.speed = 1.5

        let spring = CASpringAnimation(keyPath: "position.y")
        spring.fromValue = anticipation.toValue
        spring.toValue = toValue
        spring.duration = Constants.animationDuration * (1 - Constants.anticipationDurationRatio)
        spring.beginTime = anticipation.duration
        spring.initialVelocity = Constants.springInitialVelocity
        spring.damping = Constants.springDamping
        spring.stiffness = Constants.springStiffness
        spring.mass = Constants.springObjectMass

        let group = CAAnimationGroup()
        group.animations = [anticipation, opacity, spring]
        group.duration = Constants.animationDuration
        group.fillMode = .forwards
        group.isRemovedOnCompletion = false

        return group
    }

    func animateIndicators(
        squareColor: CGColor,
        circleColor: CGColor
    ) {
        squareLayer.fillColor = squareColor
        circleLayer.fillColor = circleColor

        let squareAnimation = createColorAnimation(
            fromValue: squareLayer.presentation()?.fillColor ?? squareLayer.fillColor,
            toValue: squareColor
        )
        let circleAnimation = createColorAnimation(
            fromValue: circleLayer.presentation()?.fillColor ?? circleLayer.fillColor,
            toValue: circleColor
        )

        squareLayer.add(
            squareAnimation,
            forKey: "squareFillColor"
        )
        circleLayer.add(
            circleAnimation,
            forKey: "circleFillColor"
        )
    }

    func createColorAnimation(
        fromValue: CGColor?,
        toValue: CGColor?
    ) -> CABasicAnimation {
        let animation = CABasicAnimation(keyPath: "fillColor")
        animation.fromValue = fromValue
        animation.toValue = toValue
        animation.duration = Constants.animationDuration
        animation.fillMode = .forwards
        animation.isRemovedOnCompletion = true

        return animation
    }
}

// MARK: AnimationDirection

private extension AssetListStyleSwitcherView {
    enum AnimationDirection {
        case top
        case bottom

        var yOffset: CGFloat {
            switch self {
            case .top: return -1
            case .bottom: return 1
            }
        }
    }
}

// MARK: Constants

private extension AssetListStyleSwitcherView {
    enum Constants {
        static let rollDistance: CGFloat = 30
        static let animationDuration: CFTimeInterval = 0.4

        static let squareSize: CGFloat = 6
        static let circleSize: CGFloat = 6
        static let spacing: CGFloat = 6

        static let anticipationDistance: CGFloat = 8.0
        static let anticipationDurationRatio: CGFloat = 0.35

        static let springInitialVelocity = 0.0
        static let springDamping: CGFloat = 15.0
        static let springStiffness: CGFloat = 150
        static let springObjectMass: CGFloat = 0.8

        static let labelContainerHeight: CGFloat = 30.0
        static let labelContainerWidth: CGFloat = 95.0

        static let indicatorContainerHeight: CGFloat = 24
        static let indicatorContainerWidth: CGFloat = 16

        static let indicatorActiveColor: CGColor = R.color.colorIconPrimary()!.cgColor
        static let indicatorInactiveColor: CGColor = R.color.colorIconInactive()!.cgColor
    }
}
