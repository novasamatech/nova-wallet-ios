import UIKit

final class GladingFrostedCardView: UIView {
    private static let basePatternOpacity: CGFloat = 0.5

    let backgroundImage = R.image.frostCardBg()!

    private let basePatternView: UIImageView = .create { view in
        view.image = R.image.frostCardPattern()
        view.contentMode = .scaleAspectFill
        view.alpha = GladingFrostedCardView.basePatternOpacity
        view.clipsToBounds = true
    }

    let highlightPatternView: GladingPatternView = .create { view in
        view.bind(model: .frostPattern)
    }

    let strokeGladingView: GladingRectView = .create { view in
        view.bind(model: .cardStrokeGlading)
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
        layer.cornerRadius = 12
    }

    private func setupLayout() {
        addSubview(basePatternView)
        basePatternView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        addSubview(highlightPatternView)
        highlightPatternView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        addSubview(strokeGladingView)
        strokeGladingView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
}

extension GladingFrostedCardView: AnimationUpdatibleView {
    func updateLayerAnimationIfActive() {
        highlightPatternView.updateLayerAnimationIfActive()
        strokeGladingView.updateLayerAnimationIfActive()
    }
}
