import UIKit

final class SwapRouteDetailsViewLayout: ScrollableContainerLayoutView {
    let titleView: MultiValueView = .create { view in
        view.valueTop.apply(style: .boldTitle1Primary)
        view.valueTop.textAlignment = .left
        view.valueBottom.textAlignment = .left
        view.valueBottom.apply(style: .regularSubhedlineSecondary)
        view.valueBottom.numberOfLines = 0
        view.spacing = 8
    }

    let routeDetailsView = SwapRouteDetailsView()

    override func setupLayout() {
        super.setupLayout()

        addArrangedSubview(titleView, spacingAfter: 24)
        addArrangedSubview(routeDetailsView)
    }
}
