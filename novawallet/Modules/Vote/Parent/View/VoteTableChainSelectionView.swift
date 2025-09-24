import Foundation
import UIKit_iOS

final class VoteTableChainSelectionControl: ControlView<
    TriangularedView,
    GenericTitleValueView<
        IconDetailsGenericView<GenericMultiValueView<DotsSecureView<UILabel>>>,
        UIImageView
    >
> {
    var iconImageView: UIImageView { controlContentView.titleView.imageView }

    var titleLabel: UILabel { controlContentView.titleView.detailsView.valueTop }
    var subtitleLabel: UILabel { controlContentView.titleView.detailsView.valueBottom.originalView }
    var subtitleSecureView: DotsSecureView<UILabel> { controlContentView.titleView.detailsView.valueBottom }

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
        setupImageDetailsLayout()
        setupAccessoryImageLayout()
    }

    func setupImageDetailsLayout() {
        controlContentView.titleView.spacing = Constants.iconDetailsSpacing
        controlContentView.titleView.detailsView.spacing = Constants.titleSubtitleSpacing
        controlContentView.titleView.detailsView.stackView.alignment = .leading
        controlContentView.titleView.iconWidth = Constants.iconSize.width

        subtitleSecureView.preferredSecuredHeight = Constants.subtitleSecureViewHeight

        titleLabel.snp.makeConstraints { make in
            make.height.equalTo(Constants.titleLabelHeight)
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
        self.imageViewModel?.cancel(on: iconImageView)
        iconImageView.image = nil

        self.imageViewModel = imageViewModel

        imageViewModel.loadImage(
            on: iconImageView,
            targetSize: Constants.iconSize,
            animated: true
        )
    }
}

// MARK: - Constants

private extension VoteTableChainSelectionControl {
    enum Constants {
        static let iconDetailsSpacing: CGFloat = 12.0
        static let titleSubtitleSpacing: CGFloat = 0.0

        static let iconSize: CGSize = .init(width: 32, height: 32)
        static let accessoryImageSize: CGSize = .init(width: 24, height: 24)

        static let titleLabelHeight: CGFloat = 20
        static let subtitleSecureViewHeight: CGFloat = 18
    }
}
