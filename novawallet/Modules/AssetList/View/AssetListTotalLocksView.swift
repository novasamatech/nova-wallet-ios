import Foundation
import UIKit
import UIKit_iOS

final class AssetListTotalLocksView: GenericBorderedView<IconDetailsGenericView<IconDetailsView>> {
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupLayout()
    }
}

// MARK: - Private

private extension AssetListTotalLocksView {
    func setupLayout() {
        contentInsets = Constants.locksContentInsets
        backgroundView.apply(style: .chipsOnCard)
        setupContentView = { contentView in
            contentView.imageView.image = R.image.iconBrowserSecurity()?.withTintColor(R.color.colorIconChip()!)
            contentView.detailsView.detailsLabel.font = .regularFootnote
            contentView.detailsView.detailsLabel.textColor = R.color.colorChipText()!
            contentView.spacing = 4
            contentView.detailsView.spacing = 4
            contentView.detailsView.mode = .detailsIcon
            contentView.detailsView.imageView.image = R.image.iconInfoFilled()?.kf.resize(to: Constants.infoIconSize)
        }
    }
}

// MARK: - SecurableViewProtocol

extension AssetListTotalLocksView: SecurableViewProtocol {
    func update(with viewModel: String) {
        contentView.detailsView.detailsLabel.text = viewModel
    }

    func createSecureOverlay() -> UIView? {
        let overlayContainer = GenericBorderedView<IconDetailsGenericView<IconDetailsGenericView<DotsOverlayView>>>()

        overlayContainer.contentInsets = Constants.locksContentInsets
        overlayContainer.backgroundView.apply(style: .chipsOnCard)

        overlayContainer.setupContentView = { overlayContentView in
            overlayContentView.imageView.image = R.image.iconBrowserSecurity()?.withTintColor(
                R.color.colorIconChip()!
            )
            overlayContentView.spacing = 4

            overlayContentView.detailsView.spacing = 4
            overlayContentView.detailsView.mode = .detailsIcon

            overlayContentView.detailsView.detailsView.configuration = DotsOverlayView.Configuration(
                dotSize: 4,
                spacing: 4,
                numberOfDots: 4,
                dotColor: R.color.colorChipText()!,
                alignment: .left
            )

            overlayContentView.detailsView.imageView.image = R.image.iconInfoFilled()?.kf.resize(
                to: Constants.infoIconSize
            )
        }

        return overlayContainer
    }
}

// MARK: - Constants

private extension AssetListTotalLocksView {
    private enum Constants {
        static let locksContentInsets = UIEdgeInsets(top: 2, left: 6, bottom: 2, right: 6)
        static let infoIconSize = CGSize(width: 12, height: 12)
    }
}
