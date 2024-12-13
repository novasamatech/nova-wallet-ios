import UIKit

protocol RouteItemViewProtocol {
    associatedtype Style
    associatedtype ViewModel

    func bind(routeItemViewModel: ViewModel)
    func apply(routeItemStyle: Style)
}

protocol RouteSeparatorViewProtocol {
    associatedtype Style

    func apply(routeSeparatorStyle: Style)
}

typealias RouteItemView = UIView & RouteItemViewProtocol
typealias RouteSeparatorView = UIView & RouteSeparatorViewProtocol

final class RouteView<I: RouteItemView, S: RouteSeparatorView>: UIView {
    private var itemViews: [I] = []
    private var separatorViews: [S] = []

    var spacing: CGFloat {
        get {
            stackView.spacing
        }

        set {
            stackView.spacing = newValue
        }
    }

    private var stackView: UIStackView = .create { view in
        view.axis = .horizontal
        view.spacing = 4
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(items: [I.ViewModel], itemStyle: I.Style, separatorStyle: S.Style) {
        let itemsToRemove = max(itemViews.count - items.count, 0)
        let itemsToAdd = max(items.count - itemViews.count, 0)

        if itemsToRemove > 0 {
            let removedItems = itemViews.suffix(itemsToRemove)
            itemViews = itemViews.dropLast(itemsToRemove)

            removedItems.forEach { $0.removeFromSuperview() }

            let removedSeparators = separatorViews.suffix(itemsToRemove)
            separatorViews = separatorViews.dropLast(itemsToRemove)

            removedSeparators.forEach { $0.removeFromSuperview() }
        }

        if itemsToAdd > 0 {
            let remainedItems: Int

            if itemViews.isEmpty {
                let itemView = I()

                stackView.addArrangedSubview(itemView)
                itemViews.append(itemView)

                remainedItems = itemsToAdd - 1
            } else {
                remainedItems = itemsToAdd
            }

            (0 ..< remainedItems).forEach { _ in
                let separator = S()

                stackView.addArrangedSubview(separator)
                separatorViews.append(separator)

                let itemView = I()

                stackView.addArrangedSubview(itemView)
                itemViews.append(itemView)
            }
        }

        itemViews.forEach { $0.apply(routeItemStyle: itemStyle) }

        zip(itemViews, items).forEach { $0.0.bind(routeItemViewModel: $0.1) }

        separatorViews.forEach { $0.apply(routeSeparatorStyle: separatorStyle) }
    }

    func getItems() -> [I] {
        itemViews
    }

    func getSeparators() -> [S] {
        separatorViews
    }

    private func setupLayout() {
        addSubview(stackView)
        stackView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
}
