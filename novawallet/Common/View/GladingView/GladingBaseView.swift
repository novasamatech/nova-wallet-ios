import UIKit

class GladingBaseView: UIView {
    let gradientView = MultigradientView()
    let gradientContentView = UIView()

    private var calculatedBounds: CGSize = .zero

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupStyle()

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        if calculatedBounds != bounds.size {
            applyOnBoundsChange()
        }
    }

    func setupStyle() {
        backgroundColor = .clear
    }

    func setupLayout() {
        addSubview(gradientContentView)
        gradientContentView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        gradientContentView.addSubview(gradientView)
        gradientView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    func applyMask() {
        fatalError("Override in child class")
    }

    func applyMotion() {
        fatalError("Override in child class")
    }

    private func applyOnBoundsChange() {
        calculatedBounds = bounds.size

        applyMask()
        applyMotion()
    }
}

extension GladingBaseView: AnimationUpdatibleView {
    func updateLayerAnimationIfActive() {
        applyMask()
        applyMotion()
    }
}
