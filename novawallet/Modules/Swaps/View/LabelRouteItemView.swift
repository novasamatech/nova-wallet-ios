import UIKit

final class LabelRouteItemView: UILabel, RouteItemViewProtocol {
    typealias ViewModel = String

    func bind(routeItemViewModel: ViewModel) {
        text = routeItemViewModel
    }

    func apply(routeItemStyle: Style) {
        apply(style: routeItemStyle)
    }
}
