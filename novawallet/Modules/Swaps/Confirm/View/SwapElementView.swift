import UIKit
import UIKit_iOS
import SnapKit

final class SwapElementView: UIView {
    var contentInsets: UIEdgeInsets = .init(top: 16, left: 12, bottom: 20, right: 12) {
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

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = .clear

        setupLayout()
    }

    lazy var contentView = UIView()

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        addSubview(backgroundView)
        addSubview(contentView)

        contentView.addSubview(assetIconView)
        contentView.addSubview(valueLabel)
        contentView.addSubview(priceLabel)
        contentView.addSubview(hubIconNameView)

        assetIconView.snp.makeConstraints {
            $0.width.height.equalTo(48)
            $0.top.centerX.equalToSuperview()
        }

        valueLabel.snp.makeConstraints {
            $0.top.equalTo(assetIconView.snp.bottom).offset(8)
            $0.leading.trailing.equalToSuperview()
        }

        priceLabel.snp.makeConstraints {
            $0.top.equalTo(valueLabel.snp.bottom).offset(2)
            $0.leading.trailing.equalToSuperview()
        }

        hubIconNameView.snp.makeConstraints {
            $0.top.equalTo(priceLabel.snp.bottom).offset(16)
            $0.leading.greaterThanOrEqualToSuperview()
            $0.trailing.lessThanOrEqualToSuperview()
            $0.centerX.equalToSuperview().priority(.high)
            $0.bottom.equalToSuperview()
        }

        backgroundView.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }

        contentView.snp.makeConstraints {
            $0.edges.equalToSuperview().inset(contentInsets)
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
        valueLabel.text = viewModel.amount
        priceLabel.text = viewModel.price ?? " "
    }
}
