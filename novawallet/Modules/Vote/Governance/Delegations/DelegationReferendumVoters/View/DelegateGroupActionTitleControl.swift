import UIKit
import UIKit_iOS

final class DelegateGroupActionTitleControl: ActionTitleControl {
    override init(frame: CGRect) {
        super.init(frame: frame)
        applyStyle()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func applyStyle() {
        backgroundColor = .clear
        indicator = ResizableImageActionIndicator(size: .init(width: 20, height: 20))
        titleLabel.apply(style: .footnotePrimary)
        identityIconAngle = CGFloat.pi / 2.0
        activationIconAngle = -CGFloat.pi / 2.0
        horizontalSpacing = 4
        imageView.isUserInteractionEnabled = false
        imageView.image = R.image.iconLinkChevron()?.tinted(with: R.color.colorIconSecondary()!)
        setContentCompressionResistancePriority(.required, for: .horizontal)
    }
}
