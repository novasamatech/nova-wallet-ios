import UIKit

final class SwapRouteDetailsView: UIView {
    private var itemListView: UIStackView?
    
    func bind(itemViewModels: [SwapRouteDetailsItemContent.ViewModel]) {
        updateItemsView(for: itemViewModels)
    }
}

private extension SwapRouteDetailsView {
    func updateItemsView(for itemViewModels: [SwapRouteDetailsItemContent.ViewModel]) {
        itemListView?.removeFromSuperview()
        
        let itemViews = itemViewModels.map { viewModel in
            let itemView = SwapRouteDetailsItemView()
            itemView.contentView.bind(viewModel: viewModel)
            return itemView
        }
        
        let itemsView = UIView.hStack(
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
