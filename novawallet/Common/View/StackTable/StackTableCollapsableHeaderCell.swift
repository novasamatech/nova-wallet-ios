import UIKit
import SnapKit
import SoraUI

final class CollapsableViewHeader: UIView {
    var titleLabel = UILabel(style: .footnoteSecondary, textAlignment: .left, numberOfLines: 1)
    var actionControl: ActionTitleControl = .create {
        $0.indicator = ResizableImageActionIndicator(size: .init(width: 24, height: 24))
        $0.imageView.image = R.image.iconLinkChevron()?.tinted(with: R.color.colorTextSecondary()!)
        $0.identityIconAngle = CGFloat.pi / 2.0
        $0.activationIconAngle = -CGFloat.pi / 2.0
        $0.titleLabel.text = nil
        $0.horizontalSpacing = 0
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = .clear

        configure()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: 24)
    }

    private func configure() {
        let contentView = UIView.hStack([
            titleLabel,
            FlexibleSpaceView(),
            actionControl
        ])

        addSubview(contentView)
        contentView.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }
    }
}
