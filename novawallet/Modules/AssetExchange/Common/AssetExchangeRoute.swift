import Foundation

struct AssetExchangeRoute {
    let items: [AssetExchangeRouteItem]
    let amount: Balance
    let direction: AssetConversion.Direction

    var quote: Balance {
        switch direction {
        case .sell:
            return items.last?.quote ?? amount
        case .buy:
            return items.first?.quote ?? amount
        }
    }

    var amountIn: Balance {
        items.first?.amountIn(for: direction) ?? amount
    }

    var amountOut: Balance {
        items.last?.amountOut(for: direction) ?? amount
    }

    func byAddingNext(item: AssetExchangeRouteItem) -> AssetExchangeRoute {
        switch direction {
        case .sell:
            return .init(items: items + [item], amount: amount, direction: direction)
        case .buy:
            return .init(items: [item] + items, amount: amount, direction: direction)
        }
    }
}

extension AssetExchangeGraphPath {
    func quoteIteration(for direction: AssetConversion.Direction) -> AssetExchangeGraphPath {
        switch direction {
        case .sell:
            self
        case .buy:
            AssetExchangeGraphPath(reversed())
        }
    }
}

struct AssetExchangeRouteItem {
    let edge: AnyAssetExchangeEdge
    let amount: Balance
    let quote: Balance

    func amountIn(for direction: AssetConversion.Direction) -> Balance {
        switch direction {
        case .sell:
            return amount
        case .buy:
            return quote
        }
    }

    func amountOut(for direction: AssetConversion.Direction) -> Balance {
        switch direction {
        case .sell:
            return quote
        case .buy:
            return amount
        }
    }
}
