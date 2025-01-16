import UIKit
import UIKit_iOS

final class ManualBackupChainTableViewCell: PlainBaseTableViewCell<ChainAccountView> {
    var networkIconView: UIImageView { contentDisplayView.networkIconView }
    var networkLabel: UILabel { contentDisplayView.networkLabel }
    var secondaryLabel: UILabel { contentDisplayView.secondaryLabel }
    var actionIconView: UIImageView { contentDisplayView.actionIconView }

    override func setupStyle() {
        super.setupStyle()

        backgroundColor = .clear
        contentView.backgroundColor = R.color.colorBlockBackground()

        actionIconView.contentMode = .scaleAspectFit
        actionIconView.image = R.image.iconSmallArrow()?.tinted(
            with: R.color.colorTextSecondary()!
        )
    }

    override func setupLayout() {
        super.setupLayout()

        contentView.layer.cornerRadius = Constants.cornerRadius
        contentView.clipsToBounds = true
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        contentView.frame = contentView.frame.inset(
            by: .init(
                top: 0,
                left: 0,
                bottom: Constants.bottomOffsetForSpacing,
                right: 0
            )
        )
    }

    func bind(with viewModel: NetworkViewModel) {
        secondaryLabel.isHidden = true

        viewModel.icon?.loadImage(
            on: networkIconView,
            targetSize: Constants.iconSize,
            animated: true
        )

        networkLabel.text = viewModel.name
    }
}

extension ManualBackupChainTableViewCell {
    enum Constants {
        static let cornerRadius: CGFloat = 12
        static let iconSize: CGSize = .init(width: 36, height: 36)
        static let bottomOffsetForSpacing: CGFloat = 8
    }
}
