import UIKit
import SoraUI

final class AssetListNftsCell: UICollectionViewCell {
    private enum Constants {
        static let mediaSize = CGSize(width: 32.0, height: 32.0)
        static let mediaStrokeSize: CGFloat = 0.0
        static let mediaCornerRadius: CGFloat = 8.0
        static let mediaSpacing: CGFloat = 20.0
        static let mediaTrailing: CGFloat = 8.0
    }

    let backgroundBlurView: TriangularedBlurView = {
        let view = TriangularedBlurView()
        view.sideLength = 12.0
        view.overlayView.highlightedFillColor = R.color.colorCellBackgroundPressed()!
        return view
    }()

    let titleLabel: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorTextPrimary()
        label.font = .regularSubheadline
        return label
    }()

    let counterLabel: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorChipText()
        label.font = .semiBoldFootnote
        return label
    }()

    let counterBackgroundView: RoundedView = {
        let view = RoundedView()
        view.apply(style: .chips)
        view.cornerRadius = 6.0
        return view
    }()

    let accessoryImageView: UIImageView = {
        let imageView = UIImageView()
        let image = R.image.iconSmallArrow()?
            .withRenderingMode(.alwaysTemplate)
            .tinted(with: R.color.colorIconSecondary()!)
        imageView.image = image
        return imageView
    }()

    private var mediaViews: [NftMediaView] = []

    var locale = Locale.current {
        didSet {
            if oldValue != locale {
                setupLocalization()
            }
        }
    }

    override var isHighlighted: Bool {
        didSet {
            if isHighlighted {
                backgroundBlurView.set(highlighted: true, animated: false)
            } else {
                backgroundBlurView.set(highlighted: false, animated: oldValue)
            }
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
    }

    private func setupLocalization() {
        titleLabel.text = R.string.localizable.walletListYourNftsTitle(preferredLanguages: locale.rLanguages)
    }

    func bind(viewModel: AssetListNftsViewModel) {
        switch viewModel.totalCount {
        case let .cached(value), let .loaded(value):
            counterLabel.text = value
        case .loading:
            counterLabel.text = ""
        }

        bind(mediaViewModels: viewModel.mediaViewModels)
    }

    func refresh() {
        mediaViews.forEach { $0.refreshMediaIfNeeded() }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func bind(mediaViewModels: [NftMediaViewModelProtocol]) {
        let numberOfImagesToCreate = mediaViewModels.count - mediaViews.count

        if numberOfImagesToCreate > 0 {
            let newMediaViews = (0 ..< numberOfImagesToCreate).map { number in
                createMediaView(isLast: number == 0)
            }
            mediaViews = updatingMediaViewList(mediaViews, appending: newMediaViews)
        } else if numberOfImagesToCreate < 0 {
            let viewsToClear = mediaViews.suffix(-numberOfImagesToCreate)
            viewsToClear.forEach { $0.removeFromSuperview() }

            mediaViews = Array(mediaViews.prefix(mediaViewModels.count))
        }

        let imageSize = CGSize(
            width: Constants.mediaSize.width - 2 * Constants.mediaStrokeSize,
            height: Constants.mediaSize.height - 2 * Constants.mediaStrokeSize
        )

        mediaViewModels.reversed().enumerated().forEach { index, viewModel in
            mediaViews[index].bind(
                viewModel: viewModel,
                targetSize: imageSize,
                cornerRadius: Constants.mediaCornerRadius
            )
        }
    }

    private func createMediaView(isLast: Bool) -> NftMediaView {
        let mediaView = NftMediaView()
        mediaView.apply(style: isLast ? .lastNft : .nft)
        mediaView.contentInsets = .zero

        return mediaView
    }

    private func updatingMediaViewList(_ list: [NftMediaView], appending: [NftMediaView]) -> [NftMediaView] {
        let views = appending.reduce(list) { result, mediaView in
            contentView.addSubview(mediaView)

            if let previousView = result.last {
                mediaView.snp.makeConstraints { make in
                    make.trailing.equalTo(previousView.snp.trailing).offset(-Constants.mediaSpacing)
                    make.centerY.equalToSuperview()
                    make.size.equalTo(Constants.mediaSize)
                }
            } else {
                mediaView.snp.makeConstraints { make in
                    make.trailing.equalTo(accessoryImageView.snp.leading).offset(-Constants.mediaTrailing)
                    make.centerY.equalToSuperview()
                    make.size.equalTo(Constants.mediaSize)
                }
            }

            return result + [mediaView]
        }

        return views
    }

    private func setupLayout() {
        contentView.addSubview(backgroundBlurView)
        backgroundBlurView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.top.bottom.equalToSuperview()
        }

        contentView.addSubview(accessoryImageView)
        accessoryImageView.snp.makeConstraints { make in
            make.trailing.equalTo(backgroundBlurView.snp.trailing).offset(-16.0)
            make.centerY.equalToSuperview()
        }

        contentView.addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.leading.equalTo(backgroundBlurView.snp.leading).offset(16.0)
            make.centerY.equalToSuperview()
        }

        contentView.addSubview(counterBackgroundView)
        counterBackgroundView.snp.makeConstraints { make in
            make.leading.equalTo(titleLabel.snp.trailing).offset(8.0)
            make.trailing.lessThanOrEqualTo(accessoryImageView.snp.leading).offset(-8.0)
            make.centerY.equalToSuperview()
        }

        counterBackgroundView.addSubview(counterLabel)
        counterLabel.snp.makeConstraints { make in
            make.top.bottom.equalToSuperview().inset(2.0)
            make.leading.trailing.equalToSuperview().inset(8.0)
        }
    }
}
