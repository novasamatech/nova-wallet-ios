import UIKit

final class GladingCardView: UIView {
    let backgroundImage = R.image.cardBg()!

    let bigPatternView: GladingPatternView = .create { view in
        view.bind(model: .bigPattern)
    }

    let middlePatternView: GladingPatternView = .create { view in
        view.bind(model: .middlePattern)
    }

    let smallPatternView: GladingPatternView = .create { view in
        view.bind(model: .smallPattern)
    }

    let strokeGladingView: GladingRectView = .create { view in
        view.bind(model: .cardStrokeGlading)
    }

    let fillGladingView: GladingRectView = .create { view in
        view.bind(model: .cardFillGlading)
    }

    private var smallPatternEffect: UIMotionEffect?
    private var middlePatternEffect: UIMotionEffect?

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
        setupStyle()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ rect: CGRect) {
        super.draw(rect)

        guard let context = UIGraphicsGetCurrentContext() else {
            return
        }

        let path = UIBezierPath(roundedRect: rect, cornerRadius: 12)
        context.addPath(path.cgPath)
        context.clip()

        let backgroundRect = rect.centered(for: backgroundImage.size)

        backgroundImage.draw(in: backgroundRect)
    }

    private func setupStyle() {
        backgroundColor = .clear

        clipsToBounds = true

        updateMotionEffect()
    }

    private func updateMotionEffect() {
        if let effect = smallPatternEffect {
            smallPatternView.removeMotionEffect(effect)
        }

        if let effect = middlePatternEffect {
            middlePatternView.removeMotionEffect(effect)
        }

        let smallXTilt = UIInterpolatingMotionEffect(
            keyPath: "center.x",
            type: .tiltAlongHorizontalAxis
        )

        smallXTilt.minimumRelativeValue = -25
        smallXTilt.maximumRelativeValue = 25

        let smallYTilt = UIInterpolatingMotionEffect(
            keyPath: "center.y",
            type: .tiltAlongVerticalAxis
        )

        smallYTilt.minimumRelativeValue = -10
        smallYTilt.maximumRelativeValue = 10

        let smallTilt = UIMotionEffectGroup()
        smallTilt.motionEffects = [smallXTilt, smallYTilt]

        smallPatternEffect = smallTilt
        smallPatternView.addMotionEffect(smallTilt)

        let middleXTilt = UIInterpolatingMotionEffect(
            keyPath: "center.x",
            type: .tiltAlongHorizontalAxis
        )

        middleXTilt.minimumRelativeValue = -15
        middleXTilt.maximumRelativeValue = 15

        let middleYTilt = UIInterpolatingMotionEffect(
            keyPath: "center.y",
            type: .tiltAlongVerticalAxis
        )

        middleYTilt.minimumRelativeValue = -5
        middleYTilt.maximumRelativeValue = 5

        let middleTilt = UIMotionEffectGroup()
        middleTilt.motionEffects = [middleXTilt, middleYTilt]

        middlePatternEffect = middleTilt
        middlePatternView.addMotionEffect(middleTilt)
    }

    private func setupLayout() {
        [bigPatternView, middlePatternView, smallPatternView].forEach { view in
            addSubview(view)
        }

        bigPatternView.snp.makeConstraints { make in
            make.width.equalToSuperview()
            make.leading.equalToSuperview().offset(2)
            make.top.equalToSuperview()
            make.bottom.equalToSuperview()
        }

        middlePatternView.snp.makeConstraints { make in
            make.width.equalToSuperview()
            make.leading.equalToSuperview().offset(-6)
            make.top.equalToSuperview()
            make.bottom.equalToSuperview()
        }

        smallPatternView.snp.makeConstraints { make in
            make.width.equalToSuperview()
            make.leading.equalToSuperview()
            make.top.equalToSuperview()
            make.bottom.equalToSuperview()
        }

        addSubview(fillGladingView)
        fillGladingView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        addSubview(strokeGladingView)
        strokeGladingView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
}

extension GladingCardView: AnimationUpdatibleView {
    func updateLayerAnimationIfActive() {
        updateMotionEffect()

        [bigPatternView, middlePatternView, smallPatternView, strokeGladingView, fillGladingView].forEach { view in
            view.updateLayerAnimationIfActive()
        }
    }
}
