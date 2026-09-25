import Foundation

#if DEBUG
    extension BittensorApiFixtureDocuments {
        static let rewardCount = 12
        static let operationCount = 137
        static let rewardTimestampBase: UInt64 = 1_790_236_800

        static let historySources: [(member: World.Member, netuid: UInt16)] = [
            (.cinder, 64),
            (.fjord, 4),
            (.blueHarbor, 0),
            (.fjord, 19),
            (.halcyon, 51)
        ]

        static func rewards(page: Int) -> Document {
            let items: [Document] = (0 ..< rewardCount).map { index in
                let source = historySources[index % historySources.count]

                return [
                    "sourceTimestamp": rewardTimestampBase - UInt64(index) * 7200,
                    "blockNumber": World.headBlock - UInt64(index) * 600 - 45,
                    "netuid": source.netuid,
                    "hotkey": World.validator(source.member).hotkey,
                    "reportedAmount": "\(18_400_000 + index * 731_117)",
                    "reportedPrice": World.subnet(netuid: source.netuid)?.taoPerAlpha ?? "1"
                ]
            }

            return historyPage(items, page: page, component: "rewardEvents", asOf: "2026-09-24T09:10:00Z")
        }

        static func operations(page: Int) -> Document {
            let items: [Document] = (0 ..< operationCount).map(operationItem)

            return historyPage(items, page: page, component: "operationHistory", asOf: "2026-09-24T09:12:00Z")
        }

        static func operationItem(_ index: Int) -> Document {
            let source = historySources[index % historySources.count]
            let taoAmount = "\(1 + index % 5).\(250 + index)"
            let alphaAmount = "\(20 + index).5"
            let isUnstake = index % 3 == 2
            let operationType: String? = index % 7 == 6 ? nil : (isUnstake ? "unstake" : "stake")
            let block = World.headBlock - UInt64(index) * 37
            let hoursAgo = index + 15

            return [
                "sourceEventId": "fixture-operation-\(index + 1)",
                "sourceTimestamp": String(format: "2026-09-%02ldT%02ld:15:00Z", 24 - hoursAgo / 24, 23 - hoursAgo % 24),
                "netuid": source.netuid,
                "hotkey": World.validator(source.member).hotkey,
                "reportedAmountIn": isUnstake ? alphaAmount : taoAmount,
                "reportedAmountOut": index % 10 == 9 ? "-" + alphaAmount : (isUnstake ? taoAmount : alphaAmount),
                "reportedPrice": World.subnet(netuid: source.netuid)?.taoPerAlpha ?? "1",
                "sourceExtrinsicReference": String(format: "%llu-%04ld", block, index % 9 + 1),
                "sourceOperationType": nullable(operationType)
            ]
        }

        static func historyPage(_ items: [Document], page: Int, component: String, asOf: String) -> Document {
            [
                "items": slice(items, page: page, pageSize: historyPageSize),
                "pageInfo": pageInfo(page: page, pageSize: historyPageSize, total: items.count),
                "historyScope": "TAO_APP_PARTIAL",
                "meta": [
                    "completeness": "COMPLETE",
                    "components": [component: availableComponent(asOf: asOf)]
                ]
            ]
        }
    }
#endif
