import Foundation

#if DEBUG
    struct BittensorApiFixtureSubnet {
        enum Ranking {
            case scored(
                risk: String,
                riskClass: String,
                scores: [BittensorApiFixtureScore],
                scoredValidators: UInt64,
                eligibleValidators: UInt64
            )
            case gated(reason: String)
            case unavailable(reason: String)
        }

        let netuid: UInt16
        let name: String
        let symbol: String
        let registeredAt: UInt64
        let tempo: UInt64
        let activityCutoffFactorMilli: UInt64
        let ownerHotkey: String
        let ownerColdkey: String
        let taoReserve: String
        let alphaReserve: String
        let alphaOutstanding: String
        let taoPerAlpha: String
        let rootProportion: String
        let flags: [String]
        let ranking: Ranking
    }

    extension BittensorApiFixtureWorld {
        static func scores(_ pairs: [(String, String)]) -> [BittensorApiFixtureScore] {
            pairs.map { BittensorApiFixtureScore(raw: $0.0, normalized: $0.1) }
        }

        static let subnets: [BittensorApiFixtureSubnet] = [
            BittensorApiFixtureSubnet(
                netuid: 1, name: "Apex", symbol: "α", registeredAt: 1_497_824, tempo: 99,
                activityCutoffFactorMilli: 50000,
                ownerHotkey: "5HDLqB5Fh2iC3B3D97PiSXEtgDprFhYvFYyo32WrnB4wHEK7",
                ownerColdkey: "5FR9hRN4qnAH1hAuA4Uz6fcbf8pbunGwJBw4od269GsTE9Wh",
                taoReserve: "21840.5", alphaReserve: "1902447.777523233", alphaOutstanding: "3100000.5",
                taoPerAlpha: "0.011480210", rootProportion: "0.1832", flags: [],
                ranking: .unavailable(reason: "not_refreshed")
            ),
            BittensorApiFixtureSubnet(
                netuid: 3, name: "Teutonic", symbol: "γ", registeredAt: 4_165_565, tempo: 360,
                activityCutoffFactorMilli: 13889,
                ownerHotkey: "5GeK6XWTGJ9RdJWEDwkf3acRkXaexWf4NHM34U6LQhMZKQNr",
                ownerColdkey: "5DBYMuyeN8EoMhLcj1dPABBjWqAMRwrwyhFyZMo3bPzdHkVF",
                taoReserve: "36112.25", alphaReserve: "1919638.652001137", alphaOutstanding: "4210000",
                taoPerAlpha: "0.018812004", rootProportion: "0.2711", flags: [],
                ranking: .scored(
                    risk: "34.52", riskClass: "balanced",
                    scores: scores([
                        ("0.0467", "48.77"), ("0.3544", "56.53"), ("36112.25", "0"),
                        ("4974315", "22.58"), ("0.8840", "46.4"), ("0.9133", "62.94")
                    ]),
                    scoredValidators: 12,
                    eligibleValidators: 11
                )
            ),
            BittensorApiFixtureSubnet(
                netuid: 4, name: "Targon", symbol: "δ", registeredAt: 1_411_451, tempo: 360,
                activityCutoffFactorMilli: 13889,
                ownerHotkey: "5H6WjGs6pfrVPvcVWvHbwwW6snXibYMAPvB1Yv727hzStpY2",
                ownerColdkey: "5G6yFkCtAAiTQ3GEoyjh4bbZQVkPwA62cYcPois4UnexbrbR",
                taoReserve: "52877.9", alphaReserve: "2166190.171930968", alphaOutstanding: "4905000.25",
                taoPerAlpha: "0.024410553", rootProportion: "0.2143", flags: [],
                ranking: .scored(
                    risk: "25.57", riskClass: "balanced",
                    scores: scores([
                        ("0.0405", "39.23"), ("0.3120", "47.11"), ("52877.9", "0"),
                        ("7728429", "0"), ("0.9102", "35.92"), ("0.9021", "56.72")
                    ]),
                    scoredValidators: 15,
                    eligibleValidators: 13
                )
            ),
            BittensorApiFixtureSubnet(
                netuid: 8, name: "Vanta", symbol: "θ", registeredAt: 1_477_264, tempo: 360,
                activityCutoffFactorMilli: 13889,
                ownerHotkey: "5FLjXTDfmZVYsfvZdgdVGAJS7CWnu3sXpJ5CAdSMy77T8sWs",
                ownerColdkey: "5EpiS9DtERuDkJfM7J8GxAjTuhywAzxbfZDpaRraWCnMZu7Z",
                taoReserve: "44120", alphaReserve: "2195777.229740359", alphaOutstanding: "3890000",
                taoPerAlpha: "0.020093113", rootProportion: "0.1968", flags: [],
                ranking: .scored(
                    risk: "43.17", riskClass: "higherUpside",
                    scores: scores([
                        ("0.0551", "61.69"), ("0.4102", "68.93"), ("44120", "0"),
                        ("7662616", "0"), ("0.8003", "79.88"), ("0.9407", "78.17")
                    ]),
                    scoredValidators: 14,
                    eligibleValidators: 12
                )
            ),
            BittensorApiFixtureSubnet(
                netuid: 9, name: "iota", symbol: "ι", registeredAt: 1_489_797, tempo: 360,
                activityCutoffFactorMilli: 13889,
                ownerHotkey: "5FTAw1Q3YeXssS1izBZ6anfQbmrGFvEwYQiKutQsp8X549i2",
                ownerColdkey: "5GazKikmFLRzmmUaatVsnikUQGMnmSVpFZiU7os42uFzh8Ze",
                taoReserve: "18954.75", alphaReserve: "1908554.899291313", alphaOutstanding: "2750000",
                taoPerAlpha: "0.009931467", rootProportion: "0.312", flags: [],
                ranking: .scored(
                    risk: "50.84", riskClass: "higherUpside",
                    scores: scores([
                        ("0.0618", "72"), ("0.4480", "77.33"), ("18954.75", "10.96"),
                        ("7650083", "0"), ("0.7811", "87.56"), ("0.9502", "83.44")
                    ]),
                    scoredValidators: 13,
                    eligibleValidators: 12
                )
            ),
            BittensorApiFixtureSubnet(
                netuid: 19, name: "blockmachine", symbol: "t", registeredAt: 1_956_072, tempo: 7200,
                activityCutoffFactorMilli: 1000,
                ownerHotkey: "5E9x7xhCY6MSTQY42DZydiuLEDZGtA5YxvSDYMqkZmiLb64u",
                ownerColdkey: "5H7XB6efpTNxPHUJzWnt2ubmNjpHPCkJcsJiqikuMNhWLN1Y",
                taoReserve: "15630.4", alphaReserve: "1917151.257278058", alphaOutstanding: "2410000.75",
                taoPerAlpha: "0.00815293", rootProportion: "0.2854", flags: ["ohlc_short_history"],
                ranking: .scored(
                    risk: "57.95", riskClass: "higherUpside",
                    scores: scores([
                        ("0.0702", "84.92"), ("0.5013", "89.18"), ("15630.4", "18.59"),
                        ("7183808", "0"), ("0.7704", "91.84"), ("0.9611", "89.5")
                    ]),
                    scoredValidators: 11,
                    eligibleValidators: 9
                )
            ),
            BittensorApiFixtureSubnet(
                netuid: 51, name: "lium.io", symbol: "ת", registeredAt: 3_966_206, tempo: 360,
                activityCutoffFactorMilli: 33334,
                ownerHotkey: "5Ek7tV57gVpRafWxoW1bAJcHCCAz1Y24WioRZKBvxGv1vQhU",
                ownerColdkey: "5EMdbgR3qiWZaZF3Vh73iXWqBV6zNnhpvGqQuHxRsjKYsqgt",
                taoReserve: "61205.8", alphaReserve: "1920109.312883723", alphaOutstanding: "3350000",
                taoPerAlpha: "0.031876206", rootProportion: "0.1705", flags: [],
                ranking: .scored(
                    risk: "61.32", riskClass: "higherUpside",
                    scores: scores([
                        ("0.0788", "98.15"), ("0.5390", "97.56"), ("61205.8", "0"),
                        ("5173674", "17.72"), ("0.7550", "98"), ("0.9744", "96.89")
                    ]),
                    scoredValidators: 12,
                    eligibleValidators: 10
                )
            ),
            BittensorApiFixtureSubnet(
                netuid: 56, name: "Gradients", symbol: "ج", registeredAt: 4_312_927, tempo: 360,
                activityCutoffFactorMilli: 13889,
                ownerHotkey: "5EbHVF5FF4DzSARUzVYEpDSwQb4Vn5sJJjLQx9bN1AvCqKBx",
                ownerColdkey: "5G3KiSfQvTH47Jky29N1DBzzQZJkZgtLLWfzpvBb8UtWhPFd",
                taoReserve: "3100.4", alphaReserve: "234877.524522406", alphaOutstanding: "420000",
                taoPerAlpha: "0.013200071", rootProportion: "0.2409", flags: [],
                ranking: .scored(
                    risk: "84.59", riskClass: "aboveThreshold",
                    scores: scores([
                        ("0.0850", "100"), ("0.6100", "100"), ("3100.4", "82.64"),
                        ("4826953", "26.17"), ("0.7012", "100"), ("0.9900", "100")
                    ]),
                    scoredValidators: 9,
                    eligibleValidators: 7
                )
            ),
            BittensorApiFixtureSubnet(
                netuid: 64, name: "Chutes", symbol: "ش", registeredAt: 4_531_295, tempo: 360,
                activityCutoffFactorMilli: 13889,
                ownerHotkey: "5GBCaF2ekuV49ipSHxtntwHBNr8Lj3c2XYJtd8eacVwREVek",
                ownerColdkey: "5HAQXW8HcVSKCp6Se52dEePjsiFtkWqjTK9huLi1Hfa9DmTC",
                taoReserve: "187432.117", alphaReserve: "3410260.348230173", alphaOutstanding: "5120000",
                taoPerAlpha: "0.054961234", rootProportion: "0.1311", flags: [],
                ranking: .scored(
                    risk: "18.96", riskClass: "balanced",
                    scores: scores([
                        ("0.0312", "24.92"), ("0.2215", "27"), ("187432.117", "0"),
                        ("4608585", "31.5"), ("0.9611", "15.56"), ("0.8612", "34")
                    ]),
                    scoredValidators: 16,
                    eligibleValidators: 14
                )
            ),
            BittensorApiFixtureSubnet(
                netuid: 120, name: "Affine", symbol: "ⴷ", registeredAt: 5_749_344, tempo: 360,
                activityCutoffFactorMilli: 13889,
                ownerHotkey: "5CAdc3yyXY9aTCLcmfBf53t6RKXpAQAgj5w3zMaaqNKf92jQ",
                ownerColdkey: "5DVcoyhUMrUEdDPgLJP7o4EVWbL3BmLcA5w6wMorJUXZE4zc",
                taoReserve: "84.5", alphaReserve: "92618.472178836", alphaOutstanding: "160000",
                taoPerAlpha: "0.000912345", rootProportion: "0.402", flags: [],
                ranking: .gated(reason: "pool_below_min")
            )
        ]
    }
#endif
