import UIKit

final class SwapRouteItemView: LoadableIconDetailsView {
    typealias ViewModel = SwapRouteItemView.ItemViewModel
    typealias Style = SwapRouteItemView.ItemStyle
}

extension SwapRouteItemView: RouteItemViewProtocol {
    struct ItemViewModel {
        let title: String?
        let icon: ImageViewModelProtocol

        var hasTitle: Bool {
            if let title, !title.isEmpty {
                return true
            } else {
                return false
            }
        }
    }

    struct ItemStyle {
        let iconSize: CGFloat
        let labelStyle: UILabel.Style?
        let spacing: CGFloat

        init(
            iconSize: CGFloat,
            labelStyle: UILabel.Style? = nil,
            spacing: CGFloat = 0
        ) {
            self.iconSize = iconSize
            self.labelStyle = labelStyle
            self.spacing = spacing
        }
    }

    func apply(routeItemStyle: Style) {
        iconWidth = routeItemStyle.iconSize
        stackView.spacing = routeItemStyle.spacing
        mode = .iconDetails

        if let labelStyle = routeItemStyle.labelStyle {
            detailsLabel.apply(style: labelStyle)
        }
    }

    func bind(routeItemViewModel: ViewModel) {
        bind(
            viewModel: StackCellViewModel(
                details: routeItemViewModel.title ?? "",
                imageViewModel: routeItemViewModel.icon
            )
        )

        detailsLabel.isHidden = !routeItemViewModel.hasTitle
    }
}

final class SwapRouteSeparatorView: UIImageView, RouteSeparatorViewProtocol {
    typealias Style = UIImage?

    func apply(routeSeparatorStyle style: Style) {
        image = style
    }
}

typealias SwapRouteView = RouteView<SwapRouteItemView, SwapRouteSeparatorView>
