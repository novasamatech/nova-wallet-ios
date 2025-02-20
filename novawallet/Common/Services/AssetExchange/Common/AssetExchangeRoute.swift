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

    func matches(otherRoute: AssetExchangeRoute, slippage: BigRational) -> Bool {
        guard direction == otherRoute.direction else { return false }

        switch direction {
        case .sell:
            let amountOutMin = amountOut - slippage.mul(value: amountOut)

            return amountOutMin <= otherRoute.amountOut
        case .buy:
            let amountInMax = amountIn + slippage.mul(value: amountIn)

            return amountInMax >= otherRoute.amountIn
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

extension AssetExchangeRouteItem: Equatable {
    static func == (lhs: AssetExchangeRouteItem, rhs: AssetExchangeRouteItem) -> Bool {
        lhs.edge.identifier == rhs.edge.identifier &&
            lhs.amount == rhs.amount &&
            lhs.quote == rhs.quote
    }
}
