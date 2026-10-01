import Foundation

#if DEBUG
    enum BittensorApiFixtureDocuments {
        typealias Document = [String: Any]
        typealias World = BittensorApiFixtureWorld

        static let maxPage = 100

        static func nullable(_ value: Any?) -> Any {
            value ?? NSNull()
        }

        static func availableComponent(
            asOf: String,
            valueQuality: String = "REPORTED",
            sourceClass: String = "PRIMARY"
        ) -> Document {
            [
                "availability": "AVAILABLE",
                "asOf": asOf,
                "freshness": "FRESH",
                "valueQuality": valueQuality,
                "sourceClass": sourceClass
            ]
        }

        static func unavailableComponent(reason: String) -> Document {
            ["availability": "UNAVAILABLE", "availabilityReason": reason]
        }

        static func pageInfo(page: Int, pageSize: Int, total: Int) -> Document {
            var nextPage: Any = NSNull()

            if page * pageSize < total, page < maxPage {
                nextPage = page + 1
            }

            return ["page": page, "pageSize": pageSize, "total": total, "nextPage": nextPage]
        }

        static func slice<T>(_ items: [T], page: Int, pageSize: Int) -> [T] {
            let start = (page - 1) * pageSize

            guard start < items.count else {
                return []
            }

            return Array(items[start ..< min(items.count, start + pageSize)])
        }
    }

    extension BittensorApiFixtureDocuments {
        static func subnets() -> Document {
            [
                "items": World.subnets.map(subnetItem),
                "meta": [
                    "completeness": "COMPLETE",
                    "components": [
                        "subnetMetadata": availableComponent(asOf: "2026-09-24T09:25:00Z"),
                        "alphaPrices": availableComponent(asOf: "2026-09-24T09:29:30Z")
                    ]
                ]
            ]
        }

        static func subnetItem(_ subnet: BittensorApiFixtureSubnet) -> Document {
            [
                "netuid": subnet.netuid,
                "name": subnet.name,
                "symbol": subnet.symbol,
                "networkRegisteredAt": subnet.registeredAt,
                "ownerColdkey": subnet.ownerColdkey,
                "ownerHotkey": subnet.ownerHotkey,
                "tempo": subnet.tempo,
                "githubRepo": "",
                "subnetContact": "",
                "subnetUrl": "",
                "subnetWebsite": "",
                "discord": "",
                "additional": "",
                "reportedRootProportion": subnet.rootProportion,
                "taoReserve": subnet.taoReserve,
                "alphaReserve": subnet.alphaReserve,
                "alphaOutstanding": subnet.alphaOutstanding,
                "taoPerAlpha": subnet.taoPerAlpha
            ]
        }

        static func validators(netuid: UInt16) -> Document {
            let isMetagraphSupported = netuid <= World.metagraphNetuidLimit
            let hasMetagraph = isMetagraphSupported && netuid != World.metagraphUnavailableNetuid

            let metagraph: Document

            if hasMetagraph {
                metagraph = availableComponent(asOf: "2026-09-24T09:27:12.345Z")
            } else if isMetagraphSupported {
                metagraph = unavailableComponent(reason: "temporarily_unavailable")
            } else {
                metagraph = unavailableComponent(reason: "source_not_supported")
            }

            let members = isMetagraphSupported ? World.seatedMembers(netuid: netuid) : []

            return [
                "items": members.map { validatorItem($0, netuid: netuid, hasMetagraph: hasMetagraph) },
                "meta": [
                    "completeness": hasMetagraph ? "COMPLETE" : "PARTIAL",
                    "components": [
                        "validatorStakes": availableComponent(asOf: "2026-09-24T09:28:00Z"),
                        "validatorMetagraph": metagraph,
                        "validatorIdentities": availableComponent(asOf: "2026-09-24T08:00:00Z")
                    ]
                ]
            ]
        }

        static func validatorItem(_ member: World.Member, netuid: UInt16, hasMetagraph: Bool) -> Document {
            let validator = World.validator(member)
            let seat = hasMetagraph ? World.seat(of: member, netuid: netuid) : nil

            return [
                "netuid": netuid,
                "hotkey": validator.hotkey,
                "stakeSourceName": nullable(validator.stakeName),
                "identitySourceName": nullable(validator.identityName),
                "metagraphBlockNumber": nullable(seat.map { _ in World.headBlock - 20 }),
                "metagraphUid": nullable(seat?.reportedUid),
                "metagraphColdkey": nullable(seat.map { _ in validator.coldkey }),
                "reportedMeasurements": measurements(member, hasMetagraph: hasMetagraph)
            ]
        }

        static func measurements(_ member: World.Member, hasMetagraph: Bool) -> Document {
            let validator = World.validator(member)
            let index = member.rawValue

            var document: Document = [
                "validatorStake": "\(validator.alphaStake).125",
                "metagraphStake": "\(validator.alphaStake).5",
                "reportedTaoStake": "\(validator.rootStake)",
                "reportedAlphaStake": "\(validator.alphaStake)",
                "reportedNominatedStake": "\(validator.alphaStake * 9 / 10)",
                "reportedValidatorTrust": validator.validatorTrust,
                "reportedTrust": "0",
                "reportedDividend": "0.0\(index + 1)21",
                "reportedIncentive": "0",
                "reportedEmission": "\(index + 3).4185",
                "reportedTaoDividendsPerHotkey": "0.\(index + 1)6",
                "reportedAlphaDividendsPerHotkey": "\(index + 4).25"
            ]

            if !hasMetagraph {
                for key in document.keys where key != "validatorStake" {
                    document[key] = NSNull()
                }
            }

            return document
        }

        static func rootYield(page: Int, pageSize: Int) -> Document {
            let items: [Document] = [
                ("13.8421", "2952.118", "2026-09-24T00:00:00Z"),
                ("13.9107", "2949.602", "2026-09-23T00:00:00Z"),
                ("14.0233", "2951.377", "2026-09-22T00:00:00Z")
            ].map { rate, emission, timestamp in
                [
                    "metricKind": "ROOT_AGGREGATE_APY",
                    "reportedRate": rate,
                    "reportedRootEmission": emission,
                    "sourceTimestamp": timestamp
                ]
            }

            return [
                "items": slice(items, page: page, pageSize: pageSize),
                "meta": [
                    "completeness": "COMPLETE",
                    "components": [
                        "rootYield": availableComponent(asOf: "2026-09-24T06:00:00Z", sourceClass: "LEGACY")
                    ]
                ],
                "pageInfo": pageInfo(page: page, pageSize: pageSize, total: items.count)
            ]
        }

        static func alphaYield(netuid: UInt16, page: Int, pageSize: Int) -> Document {
            let members = netuid == World.rootNetuid ? [] : World.seatedMembers(netuid: netuid)

            let items: [Document] = members.map { member in
                let validator = World.validator(member)

                return [
                    "metricKind": "ALPHA_VALIDATOR_APY",
                    "netuid": netuid,
                    "hotkey": validator.hotkey,
                    "validatorName": validator.identityName ?? "",
                    "reportedRate": validator.reportedRate,
                    "reportedValidatorTrust": validator.validatorTrust,
                    "reportedAlphaDividendsPerHotkey": "\(member.rawValue + 4).25",
                    "reportedAlphaStake": "\(validator.alphaStake)",
                    "reportedNominatedStake": "\(validator.alphaStake * 9 / 10)",
                    "sourceTimestamp": "2026-09-24T06:00:00Z"
                ]
            }

            return [
                "items": slice(items, page: page, pageSize: pageSize),
                "meta": [
                    "completeness": "COMPLETE",
                    "components": ["alphaYield": availableComponent(asOf: "2026-09-24T06:00:00Z")]
                ],
                "pageInfo": pageInfo(page: page, pageSize: pageSize, total: items.count)
            ]
        }
    }
#endif
