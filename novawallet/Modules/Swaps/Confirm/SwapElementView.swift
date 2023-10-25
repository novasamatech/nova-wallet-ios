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

    let backgroundView: RoundedView = .create {
        $0.apply(style: .roundedLightCell)
    }

    let imageView: AssetIconView = .create {
        $0.contentInsets = .zero
        $0.backgroundView.cornerRadius = 24
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

    override var intrinsicContentSize: CGSize {
        .init(width: UIView.noIntrinsicMetric, height: 168)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = .clear

        setupLayout()
    }

    lazy var contentView = UIView.vStack(distribution: .equalCentering, [
        imageView,
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

        imageView.snp.makeConstraints {
            $0.height.width.equalTo(48)
        }
    }
}
