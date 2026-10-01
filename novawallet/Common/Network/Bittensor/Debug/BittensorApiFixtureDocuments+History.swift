import Foundation

#if DEBUG
    extension BittensorApiFixtureDocuments {
        struct FixtureTrade {
            let amountIn: Decimal
            let amountOut: Decimal
            let label: String?
        }

        static let operationCount = 137
        static let operationPageBoundary = 100
        static let operationMoveIndex = 44
        static let operationAmountScale = 9
        static let soldOnlyNetuid: UInt16 = 51

        static let historySources: [(member: World.Member, netuid: UInt16)] = [
            (.fjord, 4),
            (.blueHarbor, 0),
            (.fjord, 19),
            (.halcyon, soldOnlyNetuid),
            (.cinder, 64)
        ]

        static func operations(page: Int) -> Document {
            let rows = (0 ..< operationCount - 1).map(operationItem)
            let boundaryRow = rows[operationPageBoundary - 1]
            let items = Array(rows[..<operationPageBoundary] + [boundaryRow] + rows[operationPageBoundary...])

            return [
                "items": slice(items, page: page, pageSize: historyPageSize),
                "pageInfo": pageInfo(page: page, pageSize: historyPageSize, total: items.count),
                "historyScope": "TAO_APP_PARTIAL",
                "meta": [
                    "completeness": "COMPLETE",
                    "components": ["operationHistory": availableComponent(asOf: "2026-09-24T09:12:00Z")]
                ]
            ]
        }

        static func operationItem(_ index: Int) -> Document {
            let source = historySources[index % historySources.count]
            let price = operationPrice(netuid: source.netuid, index: index)
            let trade = operationTrade(index: index, netuid: source.netuid, price: price)
            let amountOut = decimalText(trade.amountOut)
            let block = World.headBlock - UInt64(index) * 37
            let hoursAgo = index + 15

            return [
                "sourceEventId": "fixture-operation-\(index + 1)",
                "sourceTimestamp": String(format: "2026-09-%02ldT%02ld:15:00Z", 24 - hoursAgo / 24, 23 - hoursAgo % 24),
                "netuid": source.netuid,
                "hotkey": World.validator(source.member).hotkey,
                "reportedAmountIn": decimalText(trade.amountIn),
                "reportedAmountOut": index % 10 == 9 ? "-" + amountOut : amountOut,
                "reportedPrice": decimalText(price),
                "sourceExtrinsicReference": String(format: "%llu-%04ld", block, index % 9 + 1),
                "sourceOperationType": nullable(trade.label)
            ]
        }

        static func operationPrice(netuid: UInt16, index: Int) -> Decimal {
            guard
                let subnet = World.subnet(netuid: netuid),
                let spot = Decimal(string: subnet.taoPerAlpha, locale: Locale(identifier: "en_US_POSIX")) else {
                return 1
            }

            return spot * Decimal(1000 - index) / 1000
        }

        static func operationTrade(index: Int, netuid: UInt16, price: Decimal) -> FixtureTrade {
            let alphaAmount = Decimal(10 * (20 + index) + 5) / 10

            guard index != operationMoveIndex else {
                return FixtureTrade(amountIn: alphaAmount, amountOut: alphaAmount, label: "move")
            }

            let label: String? = index % 7 == 6 ? nil : "trade"

            if netuid == soldOnlyNetuid || index % 3 == 2 {
                return FixtureTrade(amountIn: alphaAmount, amountOut: rounded(alphaAmount * price), label: label)
            }

            let taoAmount = Decimal(1000 * (1 + index % 5) + 250 + index) / 1000

            return FixtureTrade(amountIn: taoAmount, amountOut: rounded(taoAmount / price), label: label)
        }

        static func rounded(_ value: Decimal) -> Decimal {
            var source = value
            var result = Decimal()

            NSDecimalRound(&result, &source, operationAmountScale, .plain)

            return result
        }

        static func decimalText(_ value: Decimal) -> String {
            NSDecimalNumber(decimal: value).stringValue
        }
    }
#endif
