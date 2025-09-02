import UIKit
import UIKit_iOS

class AssetListStyleSwitcher: ControlView<UIView, AssetListStyleSwitcherView> {
    convenience init() {
        self.init(frame: .zero)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        setup()
    }

    func setup() {
        changesContentOpacityWhenHighlighted = true
        contentInsets = .zero

        addTarget(self, action: #selector(handleTap), for: .touchUpInside)

        controlContentView.delegate = self
    }

    @objc func handleTap() {
        controlContentView.handleTap()

        sendActions(for: .valueChanged)
    }
}

extension AssetListStyleSwitcher: AssetListStyleSwitcherAnimationDelegate {
    func didStartAnimating() {
        isUserInteractionEnabled = false
    }

    func didEndAnimating() {
        isUserInteractionEnabled = true
    }
}
