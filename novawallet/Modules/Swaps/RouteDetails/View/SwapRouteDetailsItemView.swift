import UIKit

final class SwapRouteDetailsItemView: GenericBorderedView<SwapRouteDetailsItemContent> {
    override init(frame: CGRect) {
        super.init(frame: frame)

        configure()
    }

    private func configure() {
        contentInsets = UIEdgeInsets(verticalInset: 12, horizontalInset: 16)
        backgroundView.cornerRadius = 12
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

    private func configureAmountItemsConstraints(_ items: [AssetAmountRouteItemView]) {
        items.dropLast().forEach { itemView in
            itemView.amountLabel.setContentHuggingPriority(.high, for: .horizontal)
            itemView.amountLabel.setContentCompressionResistancePriority(.high, for: .horizontal)
        }

        guard let lastView = items.last else { return }

        lastView.amountLabel.setContentHuggingPriority(.low, for: .horizontal)
        lastView.amountLabel.setContentCompressionResistancePriority(.low, for: .horizontal)
    }

    private func configureAmountSeparatorConstraints(_ separators: [SwapRouteSeparatorView]) {
        separators.forEach { separator in
            separator.contentMode = .center
            separator.setContentHuggingPriority(.required, for: .horizontal)
            separator.setContentCompressionResistancePriority(.required, for: .horizontal)
        }
    }

    private func configureNetworkSeparatorConstraints(_ separators: [SwapRouteSeparatorView]) {
        separators.forEach { separator in
            separator.contentMode = .scaleAspectFit

            separator.snp.remakeConstraints { make in
                make.width.equalTo(12)
            }
        }
    }

    func bind(viewModel: ViewModel) {
        titleLabel.text = viewModel.type

        amountView.bind(
            items: viewModel.amountItems,
            itemStyle: AssetAmountRouteItemView.Style(
                imageSize: 24,
                amountStyle: .semiboldBodyPrimary,
                spacing: 4
            ),
            separatorStyle: R.image.iconForward()
        )

        feeView.text = viewModel.fee

        networkView.bind(
            items: viewModel.networkItems,
            itemStyle: .caption1Secondary,
            separatorStyle: R.image.iconForward()
        )

        configureAmountItemsConstraints(amountView.getItems())
        configureAmountSeparatorConstraints(amountView.getSeparators())
        configureNetworkSeparatorConstraints(networkView.getSeparators())
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
