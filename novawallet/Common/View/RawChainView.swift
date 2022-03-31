import UIKit

final class RawChainView: BorderedIconLabelView {
    override init(frame: CGRect) {
        super.init(frame: frame)

        configureStyle()
    }

    private var iconViewModel: ImageViewModelProtocol?

    private func configureStyle() {
        iconDetailsView.mode = .iconDetails
        iconDetailsView.iconWidth = 16.0
        iconDetailsView.spacing = 3.0

        iconDetailsView.detailsLabel.textColor = R.color.colorTransparentText()!
        iconDetailsView.detailsLabel.font = .semiBoldCaps2

        contentInsets = UIEdgeInsets(top: 0.0, left: 3.0, bottom: 0.0, right: 6.0)

        backgroundView.fillColor = R.color.colorWhite16()!
        backgroundView.cornerRadius = 3.0
    }

    func bind(name: String, iconViewModel: ImageViewModelProtocol?) {
        iconViewModel?.cancel(on: iconDetailsView.imageView)

        self.iconViewModel = iconViewModel

        let iconSize = iconDetailsView.iconWidth
        let settings = ImageViewModelSettings(
            targetSize: CGSize(width: iconSize, height: iconSize),
            cornerRadius: nil,
            tintColor: R.color.colorTransparentText()!
        )

        iconViewModel?.loadImage(on: iconDetailsView.imageView, settings: settings, animated: true)

        iconDetailsView.detailsLabel.text = name.uppercased()
    }
}
