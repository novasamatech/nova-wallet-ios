import UIKit
import UIKit_iOS

final class SwapReviewPairView: UIView {
    let payCardView = SwapElementView(style: .review)
    let receiveCardView = SwapElementView(style: .review)

    let arrowBackgroundView: RoundedView = .create {
        $0.apply(style: .swapReviewArrow)
    }

    let arrowImageView: UIImageView = .create {
        $0.image = R.image.iconForwardPrimary()?.tinted(with: R.color.colorTextSecondary()!)
        $0.contentMode = .scaleAspectFit
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
}

private extension SwapReviewPairView {
    func setupLayout() {
        let stackView = UIView.hStack(
            distribution: .fillEqually,
            spacing: Constants.cardsSpacing,
            [payCardView, receiveCardView]
        )

        addSubview(stackView)
        stackView.snp.makeConstraints { $0.edges.equalToSuperview() }

        addSubview(arrowBackgroundView)
        arrowBackgroundView.snp.makeConstraints {
            $0.center.equalTo(stackView)
            $0.size.equalTo(Constants.arrowSize)
        }

        arrowBackgroundView.addSubview(arrowImageView)
        arrowImageView.snp.makeConstraints {
            $0.center.equalToSuperview()
            $0.size.equalTo(Constants.arrowIconSize)
        }
    }
}

extension SwapReviewPairView {
    enum Constants {
        static let cardsSpacing: CGFloat = 8
        static let arrowSize: CGFloat = 32
        static let arrowIconSize: CGFloat = 16
    }
}

extension RoundedView.Style {
    static let swapReviewCard = RoundedView.Style(
        shadowOpacity: 0,
        strokeWidth: 1,
        strokeColor: R.color.colorContainerBorder()!,
        highlightedStrokeColor: R.color.colorContainerBorder()!,
        fillColor: R.color.colorBlockBackground()!,
        highlightedFillColor: R.color.colorBlockBackground()!,
        rounding: .init(radius: 16, corners: .allCorners)
    )

    static let swapReviewArrow = RoundedView.Style(
        shadowOpacity: 0,
        strokeWidth: 0,
        fillColor: R.color.colorGradientBlockBackgroundFirstPart()!,
        highlightedFillColor: R.color.colorGradientBlockBackgroundFirstPart()!,
        rounding: .init(radius: SwapReviewPairView.Constants.arrowSize / 2, corners: .allCorners)
    )
}

extension SwapElementView.Style {
    static let review = SwapElementView.Style(
        background: .swapReviewCard,
        contentInsets: UIEdgeInsets(top: 16, left: 12, bottom: 20, right: 12),
        iconSize: 2 * SwapElementView.assetIconRadius,
        iconInsets: UIEdgeInsets(top: 1, left: 1, bottom: 1, right: 1),
        valueOffset: 9,
        priceOffset: 4,
        hubOffset: 17,
        hubSpacing: 8,
        hubLabel: .footnoteSecondary,
        hubLabelLines: 1,
        hubHeight: nil,
        centersHub: true
    )
}
