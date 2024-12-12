import UIKit

final class SwapRouteDetailsItemView: GenericBorderedView<SwapRouteDetailsItemContent> {
    override init(frame: CGRect) {
        super.init(frame: frame)

        configure()
    }

    private func configure() {
        contentInsets = UIEdgeInsets(verticalInset: 12, horizontalInset: 16)
    }
}

final class SwapRouteDetailsItemContent: GenericMultiValueView<
    GenericPairValueView<
        RouteView<AssetAmountRouteItemView, SwapRouteSeparatorView>,
        GenericTitleValueView<UILabel, RouteView<LabelRouteItemView, SwapRouteSeparatorView>>
    >
> {
    var titleLabel: UILabel { valueTop }

    var amountView: RouteView<AssetAmountRouteItemView, SwapRouteSeparatorView> { valueBottom.fView }

    var feeView: UILabel { valueBottom.sView.titleView }

    var networkView: RouteView<LabelRouteItemView, SwapRouteSeparatorView> { valueBottom.sView.valueView }

    override init(frame: CGRect) {
        super.init(frame: frame)

        configure()
    }

    private func configure() {
        titleLabel.apply(style: .regularSubhedlinePrimary)
        titleLabel.textAlignment = .left

        feeView.apply(style: .caption1Secondary)

        spacing = 12
        valueBottom.setVerticalAndSpacing(12)
    }

    func bind(viewModel: ViewModel) {
        titleLabel.text = viewModel.type

        amountView.bind(
            items: viewModel.amountItems,
            itemStyle: AssetAmountRouteItemView.Style(
                imageSize: 18,
                amountStyle: .semiboldBodyPrimary,
                spacing: 1
            ),
            separatorStyle: R.image.iconForward()
        )

        feeView.text = viewModel.fee

        networkView.bind(
            items: viewModel.networkItems,
            itemStyle: .caption1Secondary,
            separatorStyle: R.image.iconForward()
        )
    }
}

extension SwapRouteDetailsItemContent {
    struct ViewModel {
        let type: String
        let amountItems: [AssetAmountRouteItemView.ViewModel]
        let fee: String
        let networkItems: [LabelRouteItemView.ViewModel]
    }
}
