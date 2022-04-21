import UIKit
import SoraUI

final class LinkCellView: GenericTitleValueView<UILabel, IconDetailsGenericView<RoundedButton>> {
    var actionButton: RoundedButton { valueView.detailsView }

    convenience init() {
        self.init(frame: .zero)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        configureStyle()
    }

    private func configureStyle() {
        titleView.textColor = R.color.colorTransparentText()!
        titleView.font = .regularFootnote

        let blueColor = R.color.colorNovaBlue()!

        valueView.mode = .iconDetails
        valueView.imageView.image = R.image.iconInfoFilled()?.tinted(with: blueColor)
        valueView.spacing = 5.0

        actionButton.applyIconStyle()
        actionButton.imageWithTitleView?.titleColor = blueColor
        actionButton.imageWithTitleView?.titleFont = .caption1
        actionButton.imageWithTitleView?.spacingBetweenLabelAndIcon = 0.0
        actionButton.contentInsets = UIEdgeInsets(top: 2.0, left: 0.0, bottom: 0.0, right: 0.0)
        actionButton.imageWithTitleView?.layoutType = .horizontalLabelFirst
        actionButton.imageWithTitleView?.displacementBetweenLabelAndIcon = 0.0
        actionButton.imageWithTitleView?.iconImage = R.image.iconLinkChevron()!.tinted(with: blueColor)
    }
}
