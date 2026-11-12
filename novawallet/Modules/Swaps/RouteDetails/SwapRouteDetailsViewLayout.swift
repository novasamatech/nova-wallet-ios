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

    let backgroundView = MultigradientView.background

    override func setupLayout() {
        insertSubview(backgroundView, at: 0)
        backgroundView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        super.setupLayout()

        addArrangedSubview(titleView, spacingAfter: 24)
        addArrangedSubview(routeDetailsView)
    }
}
