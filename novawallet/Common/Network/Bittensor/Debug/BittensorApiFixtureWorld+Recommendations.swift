import Foundation

#if DEBUG
    struct BittensorApiFixturePair {
        let member: BittensorApiFixtureWorld.Member
        let netuid: UInt16
        let score: String
        let validatorRisk: String
        let margin: BittensorApiFixtureScore
        let vtrust: BittensorApiFixtureScore
    }

    extension BittensorApiFixtureWorld {
        static let recommendationTopN = 3
        static let recommendationMaxTake = "0.18"
        static let takeGatePair = SeatKey(member: .delta, netuid: 64)

        static let excludedPairCount: UInt64 = 212

        static var classCounts: [String: UInt64] {
            [
                "stable": UInt64(stablePairs.count),
                "balanced": UInt64(balancedPairs.count),
                "higherUpside": UInt64(higherUpsidePairs.count),
                "excluded": excludedPairCount
            ]
        }

        static func score(_ raw: String, _ normalized: String) -> BittensorApiFixtureScore {
            BittensorApiFixtureScore(raw: raw, normalized: normalized)
        }

        static let stablePairs: [BittensorApiFixturePair] = [
            BittensorApiFixturePair(
                member: .blueHarbor,
                netuid: 0,
                score: "4.6",
                validatorRisk: "4.6",
                margin: score("0.1831", "7.36"),
                vtrust: score("0.9611", "0")
            ),
            BittensorApiFixturePair(
                member: .aster,
                netuid: 0,
                score: "14.08",
                validatorRisk: "14.08",
                margin: score("0.2466", "21.47"),
                vtrust: score("0.8930", "1.75")
            ),
            BittensorApiFixturePair(
                member: .ember,
                netuid: 0,
                score: "31.61",
                validatorRisk: "31.61",
                margin: score("0.3378", "41.73"),
                vtrust: score("0.8410", "14.75")
            )
        ]

        static let balancedPairs: [BittensorApiFixturePair] = [
            BittensorApiFixturePair(
                member: .delta,
                netuid: 64,
                score: "16.32",
                validatorRisk: "10.15",
                margin: score("0.0455", "11.92"),
                vtrust: score("0.8712", "7.2")
            ),
            BittensorApiFixturePair(
                member: .cinder,
                netuid: 64,
                score: "19.22",
                validatorRisk: "19.81",
                margin: score("0.0712", "31.69"),
                vtrust: score("0.9423", "0")
            ),
            BittensorApiFixturePair(
                member: .fjord,
                netuid: 4,
                score: "22.08",
                validatorRisk: "13.94",
                margin: score("0.0590", "22.31"),
                vtrust: score("0.9310", "0")
            )
        ]

        static let higherUpsidePairs: [BittensorApiFixturePair] = [
            BittensorApiFixturePair(
                member: .aster,
                netuid: 8,
                score: "41.82",
                validatorRisk: "38.68",
                margin: score("0.1050", "57.69"),
                vtrust: score("0.8720", "7")
            ),
            BittensorApiFixturePair(
                member: .fjord,
                netuid: 19,
                score: "50.74",
                validatorRisk: "33.9",
                margin: score("0.0931", "48.54"),
                vtrust: score("0.8620", "9.5")
            ),
            BittensorApiFixturePair(
                member: .halcyon,
                netuid: 51,
                score: "59.19",
                validatorRisk: "54.23",
                margin: score("0.1270", "74.62"),
                vtrust: score("0.8190", "20.25")
            )
        ]
    }
#endif
