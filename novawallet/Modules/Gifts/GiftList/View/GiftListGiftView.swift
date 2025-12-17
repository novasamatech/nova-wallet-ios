import Foundation
import UIKit
import UIKit_iOS

final class GiftListGiftTableViewCell: BlurredCollectionViewCell<GiftListGiftView> {
    enum Constants {
        static let innerInsetsTop: CGFloat = 4.0
        static let innerInsetsLeft: CGFloat = 12.0
        static let innerInsetsBottom: CGFloat = 4.0
        static let innerInsetsRight: CGFloat = 12.0
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        view.innerInsets = .init(
            top: Constants.innerInsetsTop,
            left: Constants.innerInsetsLeft,
            bottom: Constants.innerInsetsBottom,
            right: Constants.innerInsetsRight
        )
    }

    func bind(viewModel: GiftListGiftViewModel) {
        switch viewModel.status {
        case .pending:
            view.backgroundBlurView.contentView?.fillColor = R.color.colorGiftBlockBackground()!
            isUserInteractionEnabled = true
        case .syncing, .claimed, .reclaimed:
            view.backgroundBlurView.contentView?.fillColor = R.color.colorBlockBackground()!
            isUserInteractionEnabled = false
        }

        view.view.bind(viewModel: viewModel)
    }
}

final class GiftListGiftView: GenericPairValueView<
    GenericPairValueView<
        AssetIconView,
        GenericPairValueView<
            GenericPairValueView<
                IconDetailsGenericView<ShimmerLabel>,
                FlexibleSpaceView
            >,
            ShimmerLabel
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

    var amountView: IconDetailsGenericView<ShimmerLabel> {
        fView.sView.fView.fView
    }

    var amountLabel: ShimmerLabel {
        amountView.detailsView
    }

    var amountAccessoryImageView: UIImageView {
        amountView.imageView
    }

    var creationDateLabel: ShimmerLabel {
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
        fView.sView.fView.makeHorizontal()

        fView.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        sView.setContentHuggingPriority(.defaultHigh, for: .horizontal)

        fView.spacing = Constants.horizontalSpacing

        amountView.mode = .detailsIcon
        amountView.spacing = Constants.amountViewSpacing
        amountView.iconWidth = Constants.amountViewIconWidth

        giftImageView.snp.makeConstraints { make in
            make.size.equalTo(Constants.giftImageSize)
        }
        assetIconView.snp.makeConstraints { make in
            make.size.equalTo(Constants.assetIconSize)
        }
    }

    func setupStyle() {
        amountLabel.apply(style: .semiboldBodyPrimary)
        creationDateLabel.apply(style: .footnoteSecondary)

        assetIconView.backgroundView.cornerRadius = Constants.assetIconCornerRadius
        assetIconView.backgroundView.apply(style: .assetContainer)

        assetIconView.contentMode = .scaleAspectFit
    }

    func stopShimmering() {
        amountLabel.stopShimmering()
        creationDateLabel.stopShimmering()
    }

    func startShimmering() {
        amountLabel.startShimmering()
        creationDateLabel.startShimmering()
    }
}

// MARK: - Internal

extension GiftListGiftView {
    func bind(viewModel: GiftListGiftViewModel) {
        stopShimmering()

        viewModel.giftImageViewModel.loadImage(
            on: giftImageView,
            targetSize: CGSize(
                width: Constants.giftImageSize,
                height: Constants.giftImageSize
            ),
            animated: true
        )

        amountLabel.text = viewModel.amount
        creationDateLabel.text = viewModel.subtitle

        switch viewModel.status {
        case .pending:
            amountLabel.apply(style: .semiboldBodyPrimary)
            amountAccessoryImageView.image = R.image.iconSmallArrow()
            assetIconView.alpha = Constants.assetIconAlphaActive
        case .syncing:
            amountLabel.apply(style: .semiboldBodySecondary)
            amountAccessoryImageView.image = nil
            assetIconView.alpha = Constants.assetIconAlphaInactive
            startShimmering()
        case .claimed, .reclaimed:
            amountLabel.apply(style: .semiboldBodySecondary)
            amountAccessoryImageView.image = nil
            assetIconView.alpha = Constants.assetIconAlphaInactive
        }

        let tokenIconSettings = ImageViewModelSettings(
            targetSize: CGSize(
                width: Constants.assetIconSize,
                height: Constants.assetIconSize
            ),
            cornerRadius: nil,
            tintColor: nil
        )

        assetIconView.bind(
            viewModel: viewModel.tokenImageViewModel,
            settings: tokenIconSettings
        )
    }
}

// MARK: - Constants

private extension GiftListGiftView {
    enum Constants {
        static let horizontalSpacing: CGFloat = 12.0
        static let amountViewSpacing: CGFloat = 2.0
        static let amountViewIconWidth: CGFloat = 22.0
        static let giftImageSize: CGFloat = 56.0
        static let assetIconSize: CGFloat = 40.0
        static let assetIconCornerRadius: CGFloat = 20.0
        static let assetIconAlphaActive: CGFloat = 1.0
        static let assetIconAlphaInactive: CGFloat = 0.56
    }
}
