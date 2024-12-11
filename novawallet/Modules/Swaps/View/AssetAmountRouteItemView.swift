import Foundation
import SoraUI

final class AssetAmountRouteItemView: AssetAmountView {
    typealias ViewModel = AssetAmountRouteItemView.ItemViewModel
    typealias Style = AssetAmountRouteItemView.ItemStyle

    private var imageSize: CGFloat = 18
}

extension AssetAmountRouteItemView {
    struct ItemViewModel {
        let imageViewModel: ImageViewModelProtocol?
        let amount: String
    }

    struct ItemStyle {
        let imageSize: CGFloat
        let amountStyle: UILabel.Style
        let spacing: CGFloat
    }
}

extension AssetAmountRouteItemView: RouteItemViewProtocol {
    func bind(routeItemViewModel: ViewModel) {
        assetIconView.bind(
            viewModel: routeItemViewModel.imageViewModel, size: CGSize(width: imageSize, height: imageSize)
        )

        amountLabel.text = routeItemViewModel.amount
    }

    func apply(routeItemStyle: Style) {
        imageSize = routeItemStyle.imageSize

        assetIconView.backgroundView.cornerRadius = imageSize / 2
        amountLabel.apply(style: routeItemStyle.amountStyle)

        setHorizontalAndSpacing(routeItemStyle.spacing)
    }
}
