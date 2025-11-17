import Foundation
import UIKit
import UIKit_iOS

final class GiftListGiftTableViewCell: BlurredTableViewCell<GiftListGiftView> {
    func bind(viewModel: GiftListGiftViewModel) {
        switch viewModel.status {
        case .pending:
            backgroundBlurView.contentView?.fillColor = R.color.colorBlockBackground()!
        case .claimed, .reclaimed:
            backgroundBlurView.contentView?.fillColor = R.color.colorBlockBackgroundOpaque()!
        }

        view.bind(viewModel: viewModel)
    }
}

final class GiftListGiftView: GenericPairValueView<
    AssetIconView,
    GenericPairValueView<
        GenericPairValueView<
            IconDetailsView,
            UILabel
        >,
        UIImageView
    >
> {
    var assetIconView: AssetIconView {
        fView
    }

    var giftImageView: UIImageView {
        sView.sView
    }

    var amountView: IconDetailsView {
        sView.fView.fView
    }

    var amountLabel: UILabel {
        amountView.detailsLabel
    }

    var amountAccessoryImageView: UIImageView {
        amountView.imageView
    }

    var creationDateLabel: UILabel {
        sView.fView.sView
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
        setupStyle()
    }
}

// MARK: - Private

private extension GiftListGiftView {
    func setupLayout() {
        makeHorizontal()

        spacing = 12.0

        sView.makeHorizontal()

        sView.fView.makeVertical()
        sView.fView.spacing = 2.0

        amountView.mode = .detailsIcon
        amountView.spacing = 2.0

        sView.fView.fView.iconWidth = 22.0

        giftImageView.snp.makeConstraints { make in
            make.size.equalTo(56.0)
        }

        assetIconView.snp.makeConstraints { make in
            make.size.equalTo(40.0)
        }
    }

    func setupStyle() {
        amountLabel.apply(style: .semiboldBodyPrimary)
        creationDateLabel.apply(style: .footnoteSecondary)
    }
}

// MARK: - Internal

extension GiftListGiftView {
    func bind(viewModel: GiftListGiftViewModel) {
        viewModel.giftImageViewModel.loadImage(
            on: giftImageView,
            targetSize: CGSize(width: 56.0, height: 56.0),
            animated: true
        )

        amountLabel.text = viewModel.amount
        creationDateLabel.text = viewModel.subtitle

        var tintColor: UIColor?

        switch viewModel.status {
        case .pending:
            amountLabel.apply(style: .semiboldBodyPrimary)
            amountAccessoryImageView.image = R.image.iconSmallArrow()
        case .claimed, .reclaimed:
            amountLabel.apply(style: .semiboldBodySecondary)
            tintColor = R.color.colorIconSecondary()
            amountAccessoryImageView.image = nil
        }

        let tokenIconSettings = ImageViewModelSettings(
            targetSize: CGSize(width: 40.0, height: 40.0),
            cornerRadius: nil,
            tintColor: tintColor
        )

        assetIconView.bind(
            viewModel: viewModel.tokenImageViewModel,
            settings: tokenIconSettings
        )
    }
}
