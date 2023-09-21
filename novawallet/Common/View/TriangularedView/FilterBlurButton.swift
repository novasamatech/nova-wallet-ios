import UIKit
import SnapKit

final class FilterBlurButton: TriangularedBlurButton {
    let badgeView: UIView = .create {
        $0.backgroundColor = R.color.colorIconAccent()
        $0.clipsToBounds = true
        $0.layer.cornerRadius = 3
        $0.isHidden = true
    }

    override func configure() {
        super.configure()

        imageWithTitleView?.iconImage = R.image.iconFilterAssets()
        contentInsets = UIEdgeInsets(top: 6, left: 12, bottom: 6, right: 12)
        changesContentOpacityWhenHighlighted = true
        triangularedBlurView?.overlayView?.highlightedFillColor =
            R.color.colorCellBackgroundPressed()!

        addSubview(badgeView)

        badgeView.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-12)
            make.top.equalToSuperview().offset(6)
            make.size.equalTo(6)
        }
    }

    func bind(isFilterOn: Bool) {
        badgeView.isHidden = !isFilterOn
    }
}
