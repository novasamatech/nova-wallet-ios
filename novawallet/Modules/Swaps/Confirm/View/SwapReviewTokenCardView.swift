import UIKit
import UIKit_iOS

final class SwapReviewTokenCardView: UIView {
    let backgroundView: RoundedView = .create {
        $0.apply(style: .swapReviewCard)
    }

    let assetIconView: AssetIconView = .create {
        $0.backgroundView.cornerRadius = Constants.iconContainerSize / 2
        $0.contentInsets = Constants.iconInsets
    }

    let amountLabel = UILabel(
        style: .semiboldBodyPrimary,
        textAlignment: .center,
        numberOfLines: 1
    )

    let priceLabel = UILabel(
        style: .footnoteSecondary,
        textAlignment: .center,
        numberOfLines: 1
    )

    let networkView: IconDetailsView = .create {
        $0.mode = .iconDetails
        $0.iconWidth = Constants.networkIconSize
        $0.spacing = Constants.networkSpacing
        $0.detailsLabel.apply(style: .caption1Secondary)
        $0.detailsLabel.numberOfLines = 1
    }

    private var networkIconViewModel: ImageViewModelProtocol?

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = .clear

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension SwapReviewTokenCardView {
    func bind(viewModel: SwapAssetAmountViewModel) {
        let iconSize = Constants.iconContainerSize - Constants.iconInsets.left - Constants.iconInsets.right
        assetIconView.bind(
            viewModel: viewModel.imageViewModel,
            size: CGSize(width: iconSize, height: iconSize)
        )

        networkIconViewModel?.cancel(on: networkView.imageView)
        networkIconViewModel = viewModel.hub.icon
        viewModel.hub.icon?.loadImage(
            on: networkView.imageView,
            targetSize: CGSize(width: Constants.networkIconSize, height: Constants.networkIconSize),
            animated: true
        )

        networkView.detailsLabel.text = viewModel.hub.name
        amountLabel.text = viewModel.amount
        priceLabel.text = viewModel.price ?? " "
    }

    func bind(loadableViewModel: LoadableViewModelState<SwapAssetAmountViewModel>) {
        if let viewModel = loadableViewModel.value {
            bind(viewModel: viewModel)
        }

        switch loadableViewModel {
        case .loading, .cached:
            amountLabel.startShimmeringOpacity()
            priceLabel.startShimmeringOpacity()
        case .loaded:
            amountLabel.stopShimmeringOpacity()
            priceLabel.stopShimmeringOpacity()
        }
    }
}

private extension SwapReviewTokenCardView {
    func setupLayout() {
        addSubview(backgroundView)
        backgroundView.snp.makeConstraints { $0.edges.equalToSuperview() }

        addSubview(assetIconView)
        assetIconView.snp.makeConstraints {
            $0.top.equalToSuperview().inset(Constants.verticalInset)
            $0.centerX.equalToSuperview()
            $0.size.equalTo(Constants.iconContainerSize)
        }

        addSubview(amountLabel)
        amountLabel.snp.makeConstraints {
            $0.top.equalTo(assetIconView.snp.bottom).offset(Constants.iconBottomSpacing)
            $0.leading.trailing.equalToSuperview().inset(Constants.horizontalInset)
        }

        addSubview(priceLabel)
        priceLabel.snp.makeConstraints {
            $0.top.equalTo(amountLabel.snp.bottom).offset(Constants.amountBottomSpacing)
            $0.leading.trailing.equalToSuperview().inset(Constants.horizontalInset)
        }

        addSubview(networkView)
        networkView.snp.makeConstraints {
            $0.top.equalTo(priceLabel.snp.bottom).offset(Constants.priceBottomSpacing)
            $0.leading.equalToSuperview().inset(Constants.horizontalInset)
            $0.trailing.lessThanOrEqualToSuperview().inset(Constants.horizontalInset)
            $0.height.equalTo(Constants.networkHeight)
            $0.bottom.equalToSuperview().inset(Constants.verticalInset)
        }
    }
}

extension SwapReviewTokenCardView {
    enum Constants {
        static let verticalInset: CGFloat = 15
        static let horizontalInset: CGFloat = 17
        static let iconContainerSize: CGFloat = 42
        static let iconInsets = UIEdgeInsets(top: 1, left: 1, bottom: 1, right: 1)
        static let iconBottomSpacing: CGFloat = 4
        static let amountBottomSpacing: CGFloat = 4
        static let priceBottomSpacing: CGFloat = 4
        static let networkIconSize: CGFloat = 16
        static let networkSpacing: CGFloat = 6
        static let networkHeight: CGFloat = 16
    }
}
