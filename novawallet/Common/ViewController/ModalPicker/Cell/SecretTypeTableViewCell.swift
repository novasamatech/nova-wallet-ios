import UIKit

final class SecretTypeTableViewCell: IconWithTitleSubtitleTableViewCell {
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        let arrowIcon = R.image.iconSmallArrow()
        accessoryView = UIImageView(image: arrowIcon)

        separatorInset = UIEdgeInsets(
            top: 0.0,
            left: UIConstants.horizontalInset,
            bottom: 0.0,
            right: UIConstants.horizontalInset
        )

        titleLabel.textColor = R.color.colorWhite()
        titleLabel.font = UIFont.p1Paragraph

        subtitleLabel.textColor = R.color.colorGray()
        subtitleLabel.font = UIFont.p2Paragraph
    }
}
