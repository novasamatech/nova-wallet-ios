import UIKit
import SoraUI

final class LinkView: IconDetailsGenericView<RoundedButton> {
    var actionButton: RoundedButton { detailsView }

    convenience init() {
        self.init(frame: .zero)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        configureStyle()
    }

    private func configureStyle() {
        let blueColor = R.color.colorNovaBlue()!

        mode = .iconDetails
        imageView.image = R.image.iconInfoFilled()?.tinted(with: blueColor)
        spacing = 5.0

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
