import UIKit

class AssetListStyleSwitcherView: UIView {
    var locale = Locale.current {
        didSet {
            setupLocalizations()
        }
    }

    private var state: State = .tokens
    private var valueChanged: ((State) -> Void)?

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
        self.state = state

        setupIndicatorLayers(with: state)
        setupLocalizations()
    }

    func addAction(on valueChanged: @escaping (State) -> Void) {
        self.valueChanged = valueChanged
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
            label.text = R.string.localizable.commonNetworks(
                preferredLanguages: locale.rLanguages
            )
        case .tokens:
            label.text = R.string.localizable.commonTokens(
                preferredLanguages: locale.rLanguages
            )
        }
    }

    func setupView() {
        isUserInteractionEnabled = true
        setupSubviews()
        setupConstraints()
        setupGesture()
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

    func setupGesture() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        addGestureRecognizer(tapGesture)
    }

    func setupIndicatorLayers(with _: State) {
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
            ? R.color.colorIconPrimary()!.cgColor
            : R.color.colorIconInactive()!.cgColor
        circleLayer.position = CGPoint(x: 8, y: 16)

        circleLayer.removeFromSuperlayer()

        indicatorContainer.layer.addSublayer(circleLayer)
    }

    @objc func handleTap() {
        state.toggle()

        valueChanged?(state)

        switch state {
        case .networks:
            animateToNetworks()
        case .tokens:
            animateToTokens()
        }
    }
}

// MARK: Animation

private extension AssetListStyleSwitcherView {
    func animateToTokens() {
        animateLabels(
            newText: R.string.localizable.commonTokens(
                preferredLanguages: locale.rLanguages
            ),
            direction: .up
        )
        animateIndicators(
            squareColor: .gray,
            circleColor: .white
        )
    }

    func animateToNetworks() {
        animateLabels(
            newText: R.string.localizable.commonNetworks(
                preferredLanguages: locale.rLanguages
            ),
            direction: .down
        )
        animateIndicators(squareColor: .white, circleColor: .gray)
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
            toValue: currentPosition + (Constants.rollDistance * direction.yOffset)
        )
        let newSpring = createSpringAnimation(
            fromValue: newLabel.layer.position.y,
            toValue: currentPosition
        )

        CATransaction.begin()
        CATransaction.setCompletionBlock { [weak self] in
            self?.label.text = newText
            self?.label.layer.position.y = currentPosition
            newLabel.removeFromSuperview()
        }

        label.layer.add(currentSpring, forKey: "rollOut")
        newLabel.layer.add(newSpring, forKey: "rollIn")

        CATransaction.commit()
    }

    func createSpringAnimation(
        fromValue: Any?,
        toValue: Any?
    ) -> CASpringAnimation {
        let spring = CASpringAnimation(keyPath: "position.y")
        spring.fromValue = fromValue
        spring.toValue = toValue
        spring.duration = Constants.animationDuration
        spring.initialVelocity = Constants.springInitialVelocity
        spring.damping = Constants.springDamping
        spring.stiffness = Constants.springStiffness
        spring.mass = Constants.springObjectMass
        spring.isRemovedOnCompletion = true

        return spring
    }

    func animateIndicators(
        squareColor: UIColor,
        circleColor: UIColor
    ) {
        let squareAnimation = createColorAnimation(
            fromValue: squareLayer.fillColor ?? UIColor.white.cgColor,
            toValue: squareColor.cgColor
        )
        let circleAnimation = createColorAnimation(
            fromValue: circleLayer.fillColor ?? UIColor.gray.cgColor,
            toValue: circleColor.cgColor
        )

        squareLayer.add(
            squareAnimation,
            forKey: "fillColor"
        )
        circleLayer.add(
            circleAnimation,
            forKey: "fillColor"
        )
    }

    func createColorAnimation(
        fromValue: CGColor,
        toValue: CGColor
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
        case up, down

        var yOffset: CGFloat {
            switch self {
            case .up: return -1
            case .down: return 1
            }
        }
    }
}

// MARK: Constants

private extension AssetListStyleSwitcherView {
    enum Constants {
        static let rollDistance: CGFloat = 30
        static let animationDuration: CFTimeInterval = 0.6

        static let squareSize: CGFloat = 6
        static let circleSize: CGFloat = 6
        static let spacing: CGFloat = 6

        static let springInitialVelocity = -5.0
        static let springDamping: CGFloat = 8.0
        static let springStiffness: CGFloat = 130
        static let springObjectMass: CGFloat = 0.5

        static let labelContainerHeight: CGFloat = 30.0
        static let labelContainerWidth: CGFloat = 95.0

        static let indicatorContainerHeight: CGFloat = 24
        static let indicatorContainerWidth: CGFloat = 16
    }
}
