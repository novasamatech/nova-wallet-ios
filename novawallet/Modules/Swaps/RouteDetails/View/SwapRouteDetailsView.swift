import UIKit

final class SwapRouteDetailsView: UIView {
    private var itemListView: UIStackView?

    func bind(viewModel: SwapRouteDetailsViewModel) {
        updateItemsView(for: viewModel)
    }
}

private extension SwapRouteDetailsView {
    func updateItemsView(for itemViewModels: SwapRouteDetailsViewModel) {
        itemListView?.removeFromSuperview()

        let itemViews = itemViewModels.map { viewModel in
            let itemView = SwapRouteDetailsItemView()
            itemView.contentView.bind(viewModel: viewModel)
            return itemView
        }

        let itemsView = UIView.vStack(
            alignment: .fill,
            distribution: .fill,
            spacing: 12,
            margins: nil,
            itemViews
        )

        addSubview(itemsView)

        itemsView.snp.makeConstraints { make in
            make.top.bottom.equalToSuperview()
            make.leading.equalToSuperview().inset(40)
            make.trailing.equalToSuperview()
        }

        itemListView = itemsView
    }
}

typealias SwapRouteDetailsViewModel = [SwapRouteDetailsItemContent.ViewModel]
