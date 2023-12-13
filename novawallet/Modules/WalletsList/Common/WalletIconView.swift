import UIKit
import SnapKit

final class WalletIconView: UIView {
    enum Constants {
        static let holeWidth: CGFloat = 3
        static let iconSize = CGSize(width: 32, height: 32)
        static let networkIconSize = CGSize(width: 14, height: 14)
        static let networkIconOffset = CGPoint(x: 6, y: 4)
        static let radius: CGFloat = 4.5
    }

    let iconViewImageView = UIImageView()
    let networkIconImageView = UIImageView()

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        guard !networkIconImageView.isHidden else {
            return
        }

        iconViewImageView.layoutIfNeeded()

        let width = networkIconImageView.bounds.width + Constants.holeWidth * 2
        let height = networkIconImageView.bounds.height + Constants.holeWidth * 2
        let origin = convert(networkIconImageView.frame.origin, to: iconViewImageView)

        let frame = CGRect(
            x: origin.x - Constants.holeWidth,
            y: origin.y - Constants.holeWidth,
            width: width,
            height: height
        )

        iconViewImageView.cutHole(
            roundedRect: frame,
            cornerRadii: CGSize(
                width: Constants.radius + Constants.holeWidth / 2,
                height: Constants.radius + Constants.holeWidth / 2
            )
        )
    }

    func setupLayout() {
        addSubview(iconViewImageView)

        iconViewImageView.snp.makeConstraints {
            $0.center.equalToSuperview()
            $0.size.equalTo(Constants.iconSize)
        }

        networkIconImageView.layer.cornerRadius = Constants.radius
        addSubview(networkIconImageView)

        networkIconImageView.snp.makeConstraints {
            $0.trailing.equalTo(iconViewImageView.snp.trailing).offset(Constants.networkIconOffset.x)
            $0.bottom.equalTo(iconViewImageView.snp.bottom).offset(Constants.networkIconOffset.y)
            $0.size.equalTo(Constants.networkIconSize)
        }
    }

    override var intrinsicContentSize: CGSize {
        .init(
            width: Constants.networkIconOffset.x + Constants.iconSize.width,
            height: Constants.networkIconOffset.y + Constants.iconSize.height
        )
    }
}
