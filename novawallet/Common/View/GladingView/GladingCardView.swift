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
        view.bind(model: .cardGlading)
    }

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

        let smallTilt = UIInterpolatingMotionEffect(
            keyPath: "center.x",
            type: .tiltAlongHorizontalAxis
        )

        smallTilt.minimumRelativeValue = 25
        smallTilt.maximumRelativeValue = -25

        smallPatternView.addMotionEffect(smallTilt)

        let middleTilt = UIInterpolatingMotionEffect(
            keyPath: "center.x",
            type: .tiltAlongHorizontalAxis
        )

        middleTilt.minimumRelativeValue = 15
        middleTilt.maximumRelativeValue = -15

        middlePatternView.addMotionEffect(middleTilt)
    }

    private func setupLayout() {
        [bigPatternView, middlePatternView, smallPatternView].forEach { view in
            addSubview(view)
        }

        bigPatternView.snp.makeConstraints { make in
            make.width.equalToSuperview()
            make.leading.equalToSuperview().offset(23.5)
            make.top.equalToSuperview().offset(-25)
            make.bottom.equalToSuperview().offset(25)
        }

        middlePatternView.snp.makeConstraints { make in
            make.width.equalToSuperview()
            make.leading.equalToSuperview().offset(35.5)
            make.top.equalToSuperview().offset(-25)
            make.bottom.equalToSuperview().offset(25)
        }

        smallPatternView.snp.makeConstraints { make in
            make.width.equalToSuperview()
            make.leading.equalToSuperview().offset(5)
            make.top.equalToSuperview().offset(-25)
            make.bottom.equalToSuperview().offset(25)
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
