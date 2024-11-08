import UIKit

class BadgedManageButton: TriangularedButton {
    let badgeView: UIView = .create {
        $0.backgroundColor = R.color.colorIconAccent()
        $0.clipsToBounds = true
        $0.layer.cornerRadius = 3
        $0.isHidden = true
    }

    var icon: UIImage? = R.image.iconAssetsSettings()

    override func configure() {
        super.configure()

        imageWithTitleView?.iconImage = icon
        contentInsets = UIEdgeInsets(top: 6, left: 12, bottom: 6, right: 12)
        changesContentOpacityWhenHighlighted = true

        triangularedView?.fillColor = .clear
        triangularedView?.highlightedFillColor = .clear
        triangularedView?.shadowOpacity = 0

        addSubview(badgeView)

        badgeView.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-12)
            make.top.equalToSuperview().offset(6)
            make.size.equalTo(6)
        }
    }

    func bind(showingBadge: Bool) {
        badgeView.isHidden = !showingBadge
    }
}
