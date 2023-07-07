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
    private var bigPatternEffect: UIMotionEffect?

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
        smallPatternView.removeEffectIfNeeded(smallPatternEffect)
        middlePatternView.removeEffectIfNeeded(middlePatternEffect)
        bigPatternView.removeEffectIfNeeded(bigPatternEffect)
        
        smallPatternEffect = smallPatternView.addMotion(minX: -25, maxX: 25, minY: -19, maxY: 19)
        middlePatternEffect middlePatternView.addMotion(minX: -15, maxX: 15, minY: -8, maxY: 8)
        bigPatternEffect = bigPatternView.addMotion(minX: 7, maxX: -7, minY: 3, maxY: -3)
    }

    private func setupLayout() {
        [bigPatternView, middlePatternView, smallPatternView].forEach { view in
            addSubview(view)
        }

        bigPatternView.snp.makeConstraints { make in
            make.width.equalToSuperview()
            make.leading.equalToSuperview()
            make.top.equalToSuperview()
            make.bottom.equalToSuperview()
        }

        middlePatternView.snp.makeConstraints { make in
            make.width.equalToSuperview()
            make.leading.equalToSuperview()
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
