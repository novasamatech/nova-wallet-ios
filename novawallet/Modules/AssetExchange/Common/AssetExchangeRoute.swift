import Foundation

struct AssetExchangeRoute: Equatable {
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

extension AssetExchangeQuotePath {
    func quoteIteration(for direction: AssetConversion.Direction) -> AssetExchangeQuotePath {
        switch direction {
        case .sell:
            self
        case .buy:
            AssetExchangeQuotePath(reversed())
        }
    }
}

struct AssetExchangeRouteItem {
    let pathItem: AssetExchangeQuotePathItem
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

extension AssetExchangeRouteItem: Equatable {
    static func == (lhs: AssetExchangeRouteItem, rhs: AssetExchangeRouteItem) -> Bool {
        lhs.pathItem.edge.identifier == rhs.pathItem.edge.identifier &&
            lhs.amount == rhs.amount &&
            lhs.quote == rhs.quote
    }
}
