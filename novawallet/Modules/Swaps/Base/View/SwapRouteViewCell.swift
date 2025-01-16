import UIKit
import UIKit_iOS

final class SwapRouteViewCell: RowView<SwapGenericInfoView<SwapRouteView>>, StackTableViewCellProtocol {
    var titleButton: RoundedButton { rowContentView.titleView }
    var routeView: SwapRouteView { rowContentView.valueView }

    var itemStyle: SwapRouteItemView.Style = .init(iconSize: 16)
    var separatorStyle: SwapRouteSeparatorView.Style = R.image.iconForward()

    func bind(loadableRouteViewModel: LoadableViewModelState<[SwapRouteItemView.ItemViewModel]>) {
        switch loadableRouteViewModel {
        case let .cached(value), let .loaded(value):
            rowContentView.stopLoadingIfNeeded()

            routeView.bind(
                items: value,
                itemStyle: itemStyle,
                separatorStyle: separatorStyle
            )
        case .loading:
            rowContentView.startLoadingIfNeeded()
        }
    }
}
