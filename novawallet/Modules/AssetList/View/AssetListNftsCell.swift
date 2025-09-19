import UIKit
import UIKit_iOS

final class AssetListNftsCell: CollectionViewContainerCell<AssetListNftsView> {
    var locale: Locale {
        get { view.locale }
        set { view.locale = newValue }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        changesContentOpacityWhenHighlighted = true
    }

    func refresh() {
        view.refresh()
    }

    func bind(viewModel: AssetListNftsViewModel) {
        view.bind(viewModel: viewModel)
    }
}

final class AssetListNftsView: UIView {
    private enum Constants {
        static let mediaSize = CGSize(width: 32.0, height: 32.0)
        static let mediaStrokeSize: CGFloat = 0.0
        static let mediaCornerRadius: CGFloat = 8.0
        static let mediaSpacing: CGFloat = 20.0
        static let mediaTrailing: CGFloat = 8.0
        static let counterViewHeight: CGFloat = 22.0
    }

    private var mediaViews: [NftMediaView] = []

    let titleLabel: UILabel = .create { view in
        view.apply(style: .regularSubhedlinePrimary)
    }

    let counterView: GenericBorderedView<DotsSecureView<IconDetailsView>> = .create { view in
        view.contentView.privacyModeConfiguration = .smallBalanceChip
        view.contentView.originalView.hidesIcon = true
        view.contentView.originalView.spacing = .zero
        view.contentView.originalView.detailsLabel.apply(style: .semiboldChip)
    }

    let accessoryImageView: UIImageView = .create { view in
        view.image = R.image.iconSmallArrow()?
            .withRenderingMode(.alwaysTemplate)
            .tinted(with: R.color.colorIconSecondary()!)
    }

    var locale = Locale.current {
        didSet {
            if oldValue != locale {
                setupLocalization()
            }
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = .clear
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(viewModel: AssetListNftsViewModel) {
        switch viewModel.totalCount {
        case let .cached(value), let .loaded(value):
            counterView.contentView.originalView.bind(viewModel: value.originalContent)
            counterView.contentView.bind(value.privacyMode)
        case .loading:
            counterView.contentView.originalView.bind(viewModel: .init(title: "", icon: nil))
        }

        bind(mediaViewModels: viewModel.mediaViewModels)
    }

    func refresh() {
        mediaViews.forEach { $0.refreshMediaIfNeeded() }
    }
}

// MARK: - Private

private extension AssetListNftsView {
    func setupLocalization() {
        titleLabel.text = R.string.localizable.walletListYourNftsTitle(preferredLanguages: locale.rLanguages)
    }

    func bind(mediaViewModels: [NftMediaViewModelProtocol]) {
        let numberOfImagesToCreate = mediaViewModels.count - mediaViews.count

        if numberOfImagesToCreate > 0 {
            let newMediaViews = (0 ..< numberOfImagesToCreate).map { _ in
                createMediaView()
            }
            mediaViews = updatingMediaViewList(mediaViews, appending: newMediaViews)
        } else if numberOfImagesToCreate < 0 {
            let viewsToClear = mediaViews.suffix(-numberOfImagesToCreate)
            viewsToClear.forEach {
                $0.removeFromSuperview()
            }

            mediaViews = Array(mediaViews.prefix(mediaViewModels.count))
        }

        let imageSize = CGSize(
            width: Constants.mediaSize.width - 2 * Constants.mediaStrokeSize,
            height: Constants.mediaSize.height - 2 * Constants.mediaStrokeSize
        )

        mediaViewModels.reversed().enumerated().forEach { index, viewModel in
            let isLastNftView = index == 0
            mediaViews[index].bind(
                viewModel: viewModel,
                targetSize: imageSize,
                cornerRadius: Constants.mediaCornerRadius,
                styles: [
                    .loading: .nft,
                    .normal: isLastNftView ? .nft : .shadowedNft,
                    .placeholder: isLastNftView ? .nft : .shadowedNft
                ]
            )
        }
    }

    func createMediaView() -> NftMediaView {
        let mediaView = NftMediaView()
        mediaView.contentInsets = .zero

        return mediaView
    }

    func updatingMediaViewList(_ list: [NftMediaView], appending: [NftMediaView]) -> [NftMediaView] {
        let views = appending.reduce(list) { result, mediaView in
            addSubview(mediaView)

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

    func setupLayout() {
        addSubview(accessoryImageView)
        accessoryImageView.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(32.0)
            make.centerY.equalToSuperview()
        }

        addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(28.0)
            make.centerY.equalToSuperview()
        }

        addSubview(counterView)
        counterView.snp.makeConstraints { make in
            make.leading.equalTo(titleLabel.snp.trailing).offset(8.0)
            make.trailing.lessThanOrEqualTo(accessoryImageView.snp.leading).offset(-8.0)
            make.centerY.equalToSuperview()
            make.height.equalTo(Constants.counterViewHeight)
        }
    }
}
