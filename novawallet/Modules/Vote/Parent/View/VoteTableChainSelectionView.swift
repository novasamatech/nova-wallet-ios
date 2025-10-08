import Foundation
import UIKit_iOS

final class VoteTableChainSelectionControl: ControlView<
    TriangularedView,
    GenericTitleValueView<
        GenericPairValueView<
            AssetIconView,
            GenericMultiValueView<DotsSecureView<UILabel>>
        >,
        UIImageView
    >
> {
    var assetIconView: AssetIconView { controlContentView.titleView.fView }

    var titleLabel: UILabel { controlContentView.titleView.sView.valueTop }
    var subtitleLabel: UILabel { controlContentView.titleView.sView.valueBottom.originalView }
    var subtitleSecureView: DotsSecureView<UILabel> { controlContentView.titleView.sView.valueBottom }

    var accessoryImageView: UIImageView { controlContentView.valueView }

    private var imageViewModel: ImageViewModelProtocol?

    override init(frame: CGRect) {
        super.init(frame: frame)

        setup()
    }

    convenience init() {
        self.init(frame: .zero)
    }
}

// MARK: - Private

private extension VoteTableChainSelectionControl {
    func setup() {
        setupLayout()
        setupStyle()
    }

    // MARK: - Layout

    func setupLayout() {
        setupContentBackgroundLayout()
        setupImageDetailsLayout()
        setupAccessoryImageLayout()
    }

    func setupContentBackgroundLayout() {
        contentInsets = Constants.contentInsets
    }

    func setupImageDetailsLayout() {
        controlContentView.titleView.makeHorizontal()
        controlContentView.titleView.spacing = Constants.iconDetailsSpacing
        controlContentView.titleView.sView.spacing = Constants.titleSubtitleSpacing
        controlContentView.titleView.sView.stackView.alignment = .leading

        subtitleSecureView.preferredSecuredHeight = Constants.subtitleSecureViewHeight

        titleLabel.snp.makeConstraints { make in
            make.height.equalTo(Constants.titleLabelHeight)
        }

        assetIconView.snp.makeConstraints { make in
            make.size.equalTo(Constants.iconSize)
        }
    }

    func setupAccessoryImageLayout() {
        accessoryImageView.snp.makeConstraints { make in
            make.size.equalTo(Constants.accessoryImageSize)
        }
    }

    // MARK: - Style

    func setupStyle() {
        setupBackground()
        setupLabelStyles()
        setupAccessoryImage()
        setupAssetIconViewStyle()
    }

    func setupBackground() {
        controlBackgroundView.shadowOpacity = .zero
        controlBackgroundView.fillColor = R.color.colorBlockBackground()!
        controlBackgroundView.highlightedFillColor = R.color.colorCellBackgroundPressed()!
        controlBackgroundView.strokeColor = .clear
        controlBackgroundView.highlightedStrokeColor = .clear
        controlBackgroundView.strokeWidth = .zero
    }

    func setupLabelStyles() {
        titleLabel.apply(style: .regularSubhedlinePrimary)
        subtitleLabel.apply(style: .footnoteSecondary)
    }

    func setupAccessoryImage() {
        accessoryImageView.image = R.image.iconMore()?.withRenderingMode(.alwaysTemplate)
        accessoryImageView.tintColor = R.color.colorIconSecondary()!
    }

    func setupAssetIconViewStyle() {
        assetIconView.backgroundView.cornerRadius = Constants.iconSize.height / 2.0
        assetIconView.backgroundView.fillColor = R.color.colorTokenContainerBackground()!
        assetIconView.backgroundView.highlightedFillColor = R.color.colorContainerBackground()!
    }
}

// MARK: - Internal

extension VoteTableChainSelectionControl {
    func bind(
        title: String,
        subtitle: String?,
        privacyMode: ViewPrivacyMode
    ) {
        titleLabel.text = title
        subtitleLabel.text = subtitle

        subtitleSecureView.bind(privacyMode)
    }

    func bind(imageViewModel: ImageViewModelProtocol) {
        assetIconView.bind(viewModel: imageViewModel, size: Constants.iconSize)
    }
}

// MARK: - Constants

private extension VoteTableChainSelectionControl {
    enum Constants {
        static let iconDetailsSpacing: CGFloat = 12.0
        static let titleSubtitleSpacing: CGFloat = 0.0

        static let iconSize: CGSize = .init(width: 44, height: 44)
        static let accessoryImageSize: CGSize = .init(width: 24, height: 24)

        static let titleLabelHeight: CGFloat = 20
        static let subtitleSecureViewHeight: CGFloat = 18

        static let contentInsets: UIEdgeInsets = .init(
            top: .zero,
            left: 10.0,
            bottom: .zero,
            right: 16.0
        )
    }
}
