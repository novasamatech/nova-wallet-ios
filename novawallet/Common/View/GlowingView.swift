import UIKit
import SoraUI

final class GlowingView: UIView {
    let outerView: RoundedView = {
        let view = RoundedView()
        view.applyFilledBackgroundStyle()
        return view
    }()

    let innerView: RoundedView = {
        let view = RoundedView()
        view.applyFilledBackgroundStyle()
        return view
    }()

    var outerRadius: CGFloat = 7.0 {
        didSet {
            updateOuterSize()
            invalidateIntrinsicContentSize()
        }
    }

    var outerFillColor: UIColor = R.color.colorWhite16()! {
        didSet {
            applyOuterColor()
        }
    }

    var innerRadius: CGFloat = 3.5 {
        didSet {
            updateInnerSize()
        }
    }

    var innerFillColor: UIColor = R.color.colorWhite24()! {
        didSet {
            applyInnerColor()
        }
    }

    override var intrinsicContentSize: CGSize {
        CGSize(width: 2 * outerRadius, height: 2 * outerRadius)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func applyInitialStyle() {
        applyOuterColor()
        outerView.cornerRadius = outerRadius

        applyInnerColor()
        innerView.cornerRadius = innerRadius
    }

    private func updateInnerSize() {
        innerView.snp.updateConstraints { make in
            make.size.equalTo(2 * innerRadius)
        }

        innerView.cornerRadius = innerRadius
    }

    private func updateOuterSize() {
        outerView.snp.updateConstraints { make in
            make.size.equalTo(2 * outerRadius)
        }

        outerView.cornerRadius = outerRadius
    }

    private func applyOuterColor() {
        outerView.fillColor = outerFillColor
        outerView.highlightedFillColor = outerFillColor
    }

    private func applyInnerColor() {
        innerView.fillColor = innerFillColor
        innerView.highlightedFillColor = innerFillColor
    }

    private func setupLayout() {
        addSubview(outerView)
        outerView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
            make.size.equalTo(2 * outerRadius)
        }

        addSubview(innerView)
        innerView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.size.equalTo(2 * innerRadius)
        }
    }
}
