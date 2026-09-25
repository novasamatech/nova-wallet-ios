import Foundation

#if DEBUG
    extension BittensorApiFixtureSubnet {
        var risk: String? {
            guard case let .scored(risk, _, _, _, _) = ranking else {
                return nil
            }

            return risk
        }

        var scores: [BittensorApiFixtureScore]? {
            guard case let .scored(_, _, scores, _, _) = ranking else {
                return nil
            }

            return scores
        }
    }

    extension BittensorApiFixtureDocuments {
        static let clientChecks = ["uid", "validator_permit", "take", "last_update"]
        static let subnetMetricNames = [
            "volatility", "maxDrawdown", "poolDepth", "age", "emissionStability", "stakeConcentration"
        ]
        static let subnetMetricWeights = ["0.18", "0.12", "0.25", "0.15", "0.2", "0.1"]
        static let subnetMetricSources = ["DERIVED", "DERIVED", "REPORTED", "REPORTED", "DERIVED", "DERIVED"]
        static let priceMetricNames: Set<String> = ["volatility", "maxDrawdown", "emissionStability"]

        static func recommendations() -> Document {
            var meta = sharedRecommendationMeta()
            meta["topN"] = World.recommendationTopN
            meta["counts"] = World.classCounts

            return [
                "meta": meta,
                "classes": [
                    "stable": World.stablePairs.map(recommendationItem),
                    "balanced": World.balancedPairs.map(recommendationItem),
                    "higherUpside": World.higherUpsidePairs.map(recommendationItem)
                ]
            ]
        }

        static func rankedSubnets() -> Document {
            var meta = sharedRecommendationMeta()
            meta["policy"] = [
                "classification": "PAIR",
                "requireIdentity": true,
                "requirePositiveSignal": false,
                "insufficientHistory": "NEUTRAL"
            ]

            let scored = World.subnets
                .filter { $0.risk != nil }
                .sorted { lhs, rhs in
                    let lhsRisk = Decimal(string: lhs.risk ?? "") ?? 0
                    let rhsRisk = Decimal(string: rhs.risk ?? "") ?? 0

                    return lhsRisk == rhsRisk ? lhs.netuid < rhs.netuid : lhsRisk < rhsRisk
                }

            let others = World.subnets
                .filter { $0.risk == nil }
                .sorted { $0.netuid < $1.netuid }

            return [
                "meta": meta,
                "items": [rootRankingItem()] + (scored + others).map(rankingItem)
            ]
        }

        static func sharedRecommendationMeta() -> Document {
            [
                "completeness": "COMPLETE",
                "components": [
                    "recommendations": availableComponent(asOf: "2026-09-24T09:23:00Z", valueQuality: "DERIVED")
                ],
                "generation": [
                    "id": World.generationId,
                    "sourceBlockNumber": World.generationBlock,
                    "modelVersion": "5.0",
                    "ageSeconds": 420,
                    "servedFrom": "REDIS",
                    "excludedNetuids": [UInt16](),
                    "carriedOverNetuids": [UInt16](),
                    "inputFlags": [String]()
                ],
                "clientGates": [
                    "maxTake": World.recommendationMaxTake,
                    "requirePermit": true,
                    "requireActiveWithinCutoff": true
                ]
            ]
        }

        static func recommendationItem(_ pair: BittensorApiFixturePair) -> Document {
            let validator = World.validator(pair.member)
            let subnet = World.subnet(netuid: pair.netuid)
            let isRoot = pair.netuid == World.rootNetuid

            return [
                "netuid": pair.netuid,
                "subnetName": subnet?.name ?? World.rootName,
                "symbol": subnet?.symbol ?? World.rootSymbol,
                "uid": nullable(World.seat(of: pair.member, netuid: pair.netuid)?.reportedUid),
                "hotkey": validator.hotkey,
                "coldkey": validator.coldkey,
                "validatorName": nullable(validator.identityName),
                "score": pair.score,
                "subnetRisk": nullable(subnet?.risk),
                "validatorRisk": pair.validatorRisk,
                "breakdown": pairBreakdown(pair, subnet: subnet),
                "effectiveStakeAlpha": isRoot ? "\(validator.rootStake)" : "\(validator.alphaStake)",
                "rootStakeTao": "\(validator.rootStake)",
                "vtrust": pair.vtrust.raw ?? "0",
                "priceTao": nullable(subnet?.taoPerAlpha),
                "flags": subnet?.flags ?? [],
                "clientChecks": clientChecks
            ]
        }

        static func metric(
            _ score: BittensorApiFixtureScore,
            weight: String,
            source: String,
            flags: [String]
        ) -> Document {
            [
                "raw": nullable(score.raw),
                "normalized": score.normalized,
                "weight": weight,
                "source": source,
                "flags": flags
            ]
        }

        static func subnetBreakdown(_ subnet: BittensorApiFixtureSubnet?) -> Document? {
            guard let subnet, let scores = subnet.scores else {
                return nil
            }

            var document: Document = [:]

            for (index, name) in subnetMetricNames.enumerated() {
                document[name] = metric(
                    scores[index],
                    weight: subnetMetricWeights[index],
                    source: subnetMetricSources[index],
                    flags: priceMetricNames.contains(name) ? subnet.flags : []
                )
            }

            return document
        }

        static func pairBreakdown(_ pair: BittensorApiFixturePair, subnet: BittensorApiFixtureSubnet?) -> Document {
            var document: Document = subnetBreakdown(subnet) ?? [:]

            for name in subnetMetricNames where document[name] == nil {
                document[name] = NSNull()
            }

            let margin = metric(pair.margin, weight: "0.625", source: "DERIVED", flags: [])

            if pair.netuid == World.rootNetuid {
                document["permitMargin"] = NSNull()
                document["rootStakeMargin"] = margin
            } else {
                document["permitMargin"] = margin
                document["rootStakeMargin"] = NSNull()
            }

            document["vtrust"] = metric(pair.vtrust, weight: "0.375", source: "REPORTED", flags: [])

            return document
        }

        static func rootRankingItem() -> Document {
            [
                "netuid": World.rootNetuid,
                "subnetName": World.rootName,
                "symbol": World.rootSymbol,
                "status": "SCORED",
                "eligible": true,
                "reasons": [String](),
                "riskClass": "stable",
                "subnetRisk": NSNull(),
                "breakdown": NSNull(),
                "taoIn": NSNull(),
                "priceTao": NSNull(),
                "ageBlocks": NSNull(),
                "validators": ["scored": 64, "eligible": 41],
                "flags": [String]()
            ]
        }

        static func rankingItem(_ subnet: BittensorApiFixtureSubnet) -> Document {
            var document: Document = [
                "netuid": subnet.netuid,
                "subnetName": subnet.name,
                "symbol": subnet.symbol,
                "subnetRisk": nullable(subnet.risk),
                "breakdown": nullable(subnetBreakdown(subnet)),
                "taoIn": subnet.taoReserve,
                "priceTao": subnet.taoPerAlpha,
                "ageBlocks": World.generationBlock - subnet.registeredAt,
                "flags": subnet.flags
            ]

            switch subnet.ranking {
            case let .scored(_, riskClass, _, scoredValidators, eligibleValidators):
                document["status"] = "SCORED"
                document["eligible"] = true
                document["reasons"] = [String]()
                document["riskClass"] = riskClass
                document["validators"] = ["scored": scoredValidators, "eligible": eligibleValidators]
            case let .gated(reason):
                document.merge(unrankedFields(status: "GATED", reason: reason)) { $1 }
            case let .unavailable(reason):
                document.merge(unrankedFields(status: "UNAVAILABLE", reason: reason)) { $1 }
            }

            return document
        }

        static func unrankedFields(status: String, reason: String) -> Document {
            [
                "status": status,
                "eligible": false,
                "reasons": [reason],
                "riskClass": NSNull(),
                "validators": ["scored": 0, "eligible": 0]
            ]
        }
    }
#endif
