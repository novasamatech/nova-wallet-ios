import UIKit
import UIKit_iOS
import SnapKit

final class SwapElementView: UIView {
    var contentInsets: UIEdgeInsets {
        didSet {
            contentView.snp.updateConstraints {
                $0.edges.equalToSuperview().inset(contentInsets)
            }
        }
    }

    static let assetIconRadius: CGFloat = 24

    let backgroundView = RoundedView()

    let assetIconView = AssetIconView()

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
        $0.iconWidth = 16
        $0.mode = .iconDetails
    }

    var hidesHub: Bool = false {
        didSet {
            updateHubVisibility()
        }
    }

    private let style: Style
    private var hubImageViewModel: ImageViewModelProtocol?
    private var hubBottomConstraint: Constraint?
    private var priceBottomConstraint: Constraint?

    init(style: Style = .regular) {
        self.style = style
        contentInsets = style.contentInsets

        super.init(frame: .zero)

        backgroundColor = .clear

        applyStyle()
        setupLayout()
    }

    lazy var contentView = UIView()

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func applyStyle() {
        backgroundView.apply(style: style.background)
        assetIconView.backgroundView.cornerRadius = style.iconSize / 2
        assetIconView.contentInsets = style.iconInsets
        hubIconNameView.spacing = style.hubSpacing
        hubIconNameView.detailsLabel.apply(style: style.hubLabel)
        hubIconNameView.detailsLabel.numberOfLines = style.hubLabelLines
    }

    private func setupLayout() {
        addSubview(backgroundView)
        addSubview(contentView)

        contentView.addSubview(assetIconView)
        contentView.addSubview(valueLabel)
        contentView.addSubview(priceLabel)
        contentView.addSubview(hubIconNameView)

        assetIconView.snp.makeConstraints {
            $0.width.height.equalTo(style.iconSize)
            $0.top.centerX.equalToSuperview()
        }

        valueLabel.snp.makeConstraints {
            $0.top.equalTo(assetIconView.snp.bottom).offset(style.valueOffset)
            $0.leading.trailing.equalToSuperview()
        }

        priceLabel.snp.makeConstraints {
            $0.top.equalTo(valueLabel.snp.bottom).offset(style.priceOffset)
            $0.leading.trailing.equalToSuperview()
            priceBottomConstraint = $0.bottom.equalToSuperview().constraint
        }

        priceBottomConstraint?.deactivate()

        hubIconNameView.snp.makeConstraints {
            $0.top.equalTo(priceLabel.snp.bottom).offset(style.hubOffset)
            $0.trailing.lessThanOrEqualToSuperview()

            if style.centersHub {
                $0.leading.greaterThanOrEqualToSuperview()
                $0.centerX.equalToSuperview().priority(.high)
            } else {
                $0.leading.equalToSuperview()
            }

            if let hubHeight = style.hubHeight {
                $0.height.equalTo(hubHeight)
            }

            hubBottomConstraint = $0.bottom.equalToSuperview().constraint
        }

        backgroundView.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }

        contentView.snp.makeConstraints {
            $0.edges.equalToSuperview().inset(contentInsets)
        }
    }

    private func updateHubVisibility() {
        hubIconNameView.isHidden = hidesHub

        if hidesHub {
            hubBottomConstraint?.deactivate()
            priceBottomConstraint?.activate()
        } else {
            priceBottomConstraint?.deactivate()
            hubBottomConstraint?.activate()
        }
    }
}

extension SwapElementView {
    struct Style {
        let background: RoundedView.Style
        let contentInsets: UIEdgeInsets
        let iconSize: CGFloat
        let iconInsets: UIEdgeInsets
        let valueOffset: CGFloat
        let priceOffset: CGFloat
        let hubOffset: CGFloat
        let hubSpacing: CGFloat
        let hubLabel: UILabel.Style
        let hubLabelLines: Int
        let hubHeight: CGFloat?
        let centersHub: Bool
    }

    func bind(loadableViewModel: LoadableViewModelState<SwapAssetAmountViewModel>) {
        if let viewModel = loadableViewModel.value {
            bind(viewModel: viewModel)
        }

        switch loadableViewModel {
        case .loading, .cached:
            valueLabel.startShimmeringOpacity()
            priceLabel.startShimmeringOpacity()
        case .loaded:
            valueLabel.stopShimmeringOpacity()
            priceLabel.stopShimmeringOpacity()
        }
    }

    func bind(viewModel: SwapAssetAmountViewModel) {
        let width = style.iconSize - assetIconView.contentInsets.left - assetIconView.contentInsets.right
        let height = style.iconSize - assetIconView.contentInsets.top - assetIconView.contentInsets.bottom
        let size = CGSize(width: width, height: height)
        assetIconView.bind(viewModel: viewModel.imageViewModel, size: size)

        hubImageViewModel?.cancel(on: hubIconNameView.imageView)
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
        valueLabel.text = viewModel.amount
        priceLabel.text = viewModel.price ?? " "
    }
}

extension SwapElementView.Style {
    static let regular = SwapElementView.Style(
        background: .roundedLightCell,
        contentInsets: UIEdgeInsets(top: 16, left: 12, bottom: 20, right: 12),
        iconSize: 2 * SwapElementView.assetIconRadius,
        iconInsets: .zero,
        valueOffset: 8,
        priceOffset: 2,
        hubOffset: 16,
        hubSpacing: 8,
        hubLabel: .footnoteSecondary,
        hubLabelLines: 0,
        hubHeight: nil,
        centersHub: true
    )
}
