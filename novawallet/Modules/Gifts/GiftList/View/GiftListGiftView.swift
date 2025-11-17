import Foundation
import UIKit
import UIKit_iOS

final class GiftListGiftTableViewCell: BlurredCollectionViewCell<GiftListGiftView> {
    override init(frame: CGRect) {
        super.init(frame: frame)

        view.innerInsets = .init(
            top: 4.0,
            left: 12.0,
            bottom: 4.0,
            right: 12.0
        )
    }

    func bind(viewModel: GiftListGiftViewModel) {
        switch viewModel.status {
        case .pending:
            view.backgroundBlurView.contentView?.fillColor = R.color.colorBlockBackground()!
        case .claimed, .reclaimed:
            view.backgroundBlurView.contentView?.fillColor = R.color.colorBlockBackgroundOpaque()!
        }

        view.view.bind(viewModel: viewModel)
    }
}

final class GiftListGiftView: GenericPairValueView<
    GenericPairValueView<
        AssetIconView,
        GenericPairValueView<
            IconDetailsView,
            UILabel
        >
    >,
    GenericPairValueView<
        FlexibleSpaceView,
        UIImageView
    >
> {
    var assetIconView: AssetIconView {
        fView.fView
    }

    var giftImageView: UIImageView {
        sView.sView
    }

    var amountView: IconDetailsView {
        fView.sView.fView
    }

    var amountLabel: UILabel {
        amountView.detailsLabel
    }

    var amountAccessoryImageView: UIImageView {
        amountView.imageView
    }

    var creationDateLabel: UILabel {
        fView.sView.sView
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
        stackView.distribution = .fill
        stackView.alignment = .center

        makeHorizontal()

        fView.makeHorizontal()
        fView.sView.makeVertical()
        sView.makeHorizontal()

        fView.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        sView.setContentHuggingPriority(.defaultHigh, for: .horizontal)

        fView.spacing = 12.0

        amountView.mode = .detailsIcon
        amountView.spacing = 2.0

        fView.sView.fView.iconWidth = 22.0

        giftImageView.snp.makeConstraints { make in
            make.size.equalTo(56.0)
        }
        assetIconView.snp.makeConstraints { make in
            make.size.equalTo(40.0)
        }
        amountAccessoryImageView.snp.makeConstraints { make in
            make.size.equalTo(22.0)
        }
    }

    func setupStyle() {
        amountLabel.apply(style: .semiboldBodyPrimary)
        creationDateLabel.apply(style: .footnoteSecondary)

        assetIconView.backgroundView.cornerRadius = 20
        assetIconView.backgroundView.apply(style: .assetContainer)

        assetIconView.contentMode = .scaleAspectFit
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

        switch viewModel.status {
        case .pending:
            amountLabel.apply(style: .semiboldBodyPrimary)
            amountAccessoryImageView.image = R.image.iconSmallArrow()
            assetIconView.alpha = 1.0
        case .claimed, .reclaimed:
            amountLabel.apply(style: .semiboldBodySecondary)
            amountAccessoryImageView.image = nil
            assetIconView.alpha = 0.56
        }

        let tokenIconSettings = ImageViewModelSettings(
            targetSize: CGSize(width: 40.0, height: 40.0),
            cornerRadius: nil,
            tintColor: nil
        )

        assetIconView.bind(
            viewModel: viewModel.tokenImageViewModel,
            settings: tokenIconSettings
        )
    }
}
