import UIKit
import SoraUI

final class SwapElementView: UIView {
    var contentInsets: UIEdgeInsets = .zero {
        didSet {
            contentView.snp.updateConstraints {
                $0.edges.equalToSuperview().inset(contentInsets)
            }
        }
    }

    static let assetIconRadius: CGFloat = 24

    let backgroundView: RoundedView = .create {
        $0.apply(style: .roundedLightCell)
    }

    let assetIconView: AssetIconView = .create {
        $0.contentInsets = .zero
        $0.backgroundView.cornerRadius = SwapElementView.assetIconRadius
    }

    let valueLabel: UILabel = .init(
        style: .semiboldBodyPrimary,
        textAlignment: .center,
        numberOfLines: 1
    )

    let priceLabel: UILabel = .init(
        style: .footnoteSecondary,
        textAlignment: .center,
        numberOfLines: 1
    )

    let hubIconNameView: IconDetailsView = .create {
        $0.spacing = 8
        $0.iconWidth = 16
        $0.mode = .iconDetails
        $0.detailsLabel.apply(style: .footnoteSecondary)
    }

    private var hubImageViewModel: ImageViewModelProtocol?

    override var intrinsicContentSize: CGSize {
        .init(width: UIView.noIntrinsicMetric, height: 168)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = .clear

        setupLayout()
    }

    lazy var contentView = UIView.vStack(distribution: .equalCentering, [
        assetIconView,
        valueLabel,
        priceLabel,
        hubIconNameView
    ])

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        addSubview(backgroundView)
        addSubview(contentView)

        backgroundView.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }

        contentView.snp.makeConstraints {
            $0.edges.equalToSuperview().inset(contentInsets)
        }

        assetIconView.snp.makeConstraints {
            $0.height.width.equalTo(48)
        }
    }
}

extension SwapElementView {
    func bind(viewModel: SwapAssetAmountViewModel) {
        let width = 2 * Self.assetIconRadius - assetIconView.contentInsets.left - assetIconView.contentInsets.right
        let height = 2 * Self.assetIconRadius - assetIconView.contentInsets.top - assetIconView.contentInsets.bottom
        let size = CGSize(width: width, height: height)
        assetIconView.bind(viewModel: viewModel.imageViewModel, size: size)

        viewModel.hub.icon?.cancel(on: hubIconNameView.imageView)
        hubImageViewModel = viewModel.hub.icon
        viewModel.hub.icon?.loadImage(
            on: hubIconNameView.imageView,
            targetSize: .init(
                width: hubIconNameView.iconWidth,
                height: hubIconNameView.iconWidth
            ),
            animated: true
        )
        hubIconNameView.detailsLabel.text = viewModel.hub.name
        valueLabel.text = viewModel.balance.amount
        priceLabel.text = viewModel.balance.price
    }
}

extension SwapRateViewCell {
    func bind(attention: AttentionState) {
        switch attention {
        case .high:
            titleButton.imageWithTitleView?.titleColor = R.color.colorTextNegative()
        case .medium:
            titleButton.imageWithTitleView?.titleColor = R.color.colorTextWarning()
        case .low:
            titleButton.imageWithTitleView?.titleColor = R.color.colorTextPrimary()
        }
    }

    func bind(differenceViewModel: LoadableViewModelState<DifferenceViewModel>) {
        switch differenceViewModel {
        case .loading:
            bind(loadableViewModel: .loading)
        case let .cached(value):
            bind(attention: value.attention)
            bind(loadableViewModel: .cached(value: value.details))
        case let .loaded(value):
            bind(attention: value.attention)
            bind(loadableViewModel: .loaded(value: value.details))
        }
    }
}
