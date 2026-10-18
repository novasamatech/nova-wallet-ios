import Foundation

#if DEBUG
    struct BittensorApiFixtureScore {
        let raw: String?
        let normalized: String
    }

    struct BittensorApiFixtureRootSeat {
        let uid: UInt16
        let hasPermit: Bool
    }

    struct BittensorApiFixtureSeat: Equatable {
        let uid: UInt16
        let reportedUid: UInt16
        let hasPermit: Bool
        let lastUpdate: UInt64
    }

    struct BittensorApiFixtureValidator {
        let hotkey: String
        let coldkey: String
        let identityName: String?
        let stakeName: String?
        let take: UInt16
        let alphaStake: UInt64
        let rootStake: UInt64
        let validatorTrust: String
        let reportedRate: String
        let rootSeat: BittensorApiFixtureRootSeat?
    }

    enum BittensorApiFixtureWorld {
        enum Member: Int, CaseIterable {
            case aster
            case blueHarbor
            case cinder
            case delta
            case ember
            case fjord
            case granite
            case halcyon
        }

        struct SeatKey: Hashable {
            let member: Member
            let netuid: UInt16
        }

        static let rootNetuid: UInt16 = 0
        static let rootName = "Root"
        static let rootSymbol = "Τ"
        static let headBlock: UInt64 = 9_140_000
        static let blockHash = "0x38428b1bd24c6a06ff18b24e33e3e2033ccc384be6c08ee1d89e2bdae422047b"
        static let generationId = "8ebc85abd0bbeb6f282302ac48909c3d"
        static let generationBlock: UInt64 = 9_139_880
        static let frozenRootLastUpdate: UInt64 = 9_094_460
        static let unseatedSlotLastUpdate: UInt64 = 9_139_700
        static let rootVectorLength = 64
        static let subnetVectorLength = 256
        static let metagraphNetuidLimit: UInt16 = 256
        static let metagraphUnavailableNetuid: UInt16 = 120
        static let defaultDelegateTake: UInt16 = 11796
        static let defaultTempo: UInt64 = 360
        static let defaultActivityCutoffFactorMilli: UInt64 = 13889
        static let rootTempo: UInt64 = 100
        static let rootActivityCutoffFactorMilli: UInt64 = 50000
        static let alphaUnit: UInt64 = 1_000_000_000

        static let seatLastUpdateAges: [SeatKey: UInt64] = [
            SeatKey(member: .fjord, netuid: 19): 6000,
            SeatKey(member: .halcyon, netuid: 51): 9000,
            SeatKey(member: .halcyon, netuid: 64): 6200
        ]

        static let unpermittedSeats: Set<SeatKey> = [
            SeatKey(member: .granite, netuid: 64)
        ]

        static let reportedUidOverrides: [SeatKey: UInt16] = [
            SeatKey(member: .cinder, netuid: 64): 17
        ]

        static func validator(_ member: Member) -> BittensorApiFixtureValidator {
            validators[member.rawValue]
        }

        static func seat(of member: Member, netuid: UInt16) -> BittensorApiFixtureSeat? {
            let key = SeatKey(member: member, netuid: netuid)

            guard netuid != rootNetuid else {
                return validator(member).rootSeat.map { rootSeat in
                    BittensorApiFixtureSeat(
                        uid: rootSeat.uid,
                        reportedUid: reportedUidOverrides[key] ?? rootSeat.uid,
                        hasPermit: rootSeat.hasPermit,
                        lastUpdate: frozenRootLastUpdate
                    )
                }
            }

            guard subnet(netuid: netuid) != nil else {
                return nil
            }

            let uid = UInt16((member.rawValue * 37 + Int(netuid) * 13) % subnetVectorLength)
            let age = seatLastUpdateAges[key] ?? UInt64(12 + member.rawValue * 9)

            return BittensorApiFixtureSeat(
                uid: uid,
                reportedUid: reportedUidOverrides[key] ?? uid,
                hasPermit: !unpermittedSeats.contains(key),
                lastUpdate: headBlock - age
            )
        }

        static func seatedMembers(netuid: UInt16) -> [Member] {
            Member.allCases
                .filter { seat(of: $0, netuid: netuid) != nil }
                .sorted { validator($0).hotkey < validator($1).hotkey }
        }

        static func member(hotkey: String) -> Member? {
            Member.allCases.first { validator($0).hotkey == hotkey }
        }

        static func subnet(netuid: UInt16) -> BittensorApiFixtureSubnet? {
            subnets.first { $0.netuid == netuid }
        }

        static func activityCutoffParameters(netuid: UInt16) -> (factorMilli: UInt64, tempo: UInt64) {
            if netuid == rootNetuid {
                return (rootActivityCutoffFactorMilli, rootTempo)
            }

            guard let subnet = subnet(netuid: netuid) else {
                return (defaultActivityCutoffFactorMilli, defaultTempo)
            }

            return (subnet.activityCutoffFactorMilli, subnet.tempo)
        }

        static let validators: [BittensorApiFixtureValidator] = [
            BittensorApiFixtureValidator(
                hotkey: "5HA1KTbyJk2bHwQfcbzc962c6RsnJzwkF615k7JarmPVc4Z5",
                coldkey: "5FSf97ZrAiaB989c4eBSXa1Mw2ZqF8pqkavdr5inQNNGrUCv",
                identityName: "Aster Stake",
                stakeName: "Aster Stake",
                take: 11796,
                alphaStake: 412_000,
                rootStake: 98000,
                validatorTrust: "0.8930",
                reportedRate: "14.8812",
                rootSeat: BittensorApiFixtureRootSeat(uid: 3, hasPermit: true)
            ),
            BittensorApiFixtureValidator(
                hotkey: "5HkbYv26iGSaLnr8uYgkmUmMxc4oPtEiuWtm5vFkfdcfupJG",
                coldkey: "5EvBh97k5ZsnKQtHsJNkwoPFPPdNreUMGxaJAT3BuSFJ7Xjw",
                identityName: "Blue Harbor",
                stakeName: "BlueHarbor",
                take: 0,
                alphaStake: 158_000,
                rootStake: 145_000,
                validatorTrust: "0.9611",
                reportedRate: "16.2204",
                rootSeat: BittensorApiFixtureRootSeat(uid: 11, hasPermit: false)
            ),
            BittensorApiFixtureValidator(
                hotkey: "5C69K4avX2WsHw8zAyEpziWw4bgZxTZme4SpfXXxbLY1Tdg8",
                coldkey: "5GCXWKvq1ndwWUkTEEHxtkoXagyiouTqAfNavFhdjLtn18G9",
                identityName: "Cinder Node",
                stakeName: "Cinder Node",
                take: 6553,
                alphaStake: 231_500,
                rootStake: 0,
                validatorTrust: "0.9423",
                reportedRate: "19.0417",
                rootSeat: nil
            ),
            BittensorApiFixtureValidator(
                hotkey: "5HCUfnPn1rT2eAiJF33ZHSFGcMrDwnLePyN3fZuE7VzUVgnj",
                coldkey: "5Cw5vLH9qNzj2b2YKqS18fiMPb2kFdDyTWEDeguvBNmALo5w",
                identityName: "Delta Relay",
                stakeName: "Delta Relay",
                take: 11797,
                alphaStake: 88900,
                rootStake: 0,
                validatorTrust: "0.8712",
                reportedRate: "22.5130",
                rootSeat: nil
            ),
            BittensorApiFixtureValidator(
                hotkey: "5H1ACjwyj6GQQh7u5iVLFrxiyyZd4DTFUb7gDrv55gVprUBj",
                coldkey: "5DDsoGJWzDt2SHMs6AH1xPpvYQEf2ycUUQmjCRUr7svB1fSr",
                identityName: "Ember Labs",
                stakeName: "Ember Labs",
                take: 9830,
                alphaStake: 301_250,
                rootStake: 61000,
                validatorTrust: "0.8410",
                reportedRate: "13.3301",
                rootSeat: BittensorApiFixtureRootSeat(uid: 27, hasPermit: true)
            ),
            BittensorApiFixtureValidator(
                hotkey: "5CEpE7GVZNqEQMjwkpb4LqWGWLz1aPCiV7mMC8wm9Vibg1VR",
                coldkey: "5GpztogH8uWfQzUn1KRRY81dVDtnisuXnRLXri2wN72Mdbxo",
                identityName: "Fjord Validators",
                stakeName: "Fjord",
                take: 3276,
                alphaStake: 120_400,
                rootStake: 0,
                validatorTrust: "0.9310",
                reportedRate: "25.7788",
                rootSeat: nil
            ),
            BittensorApiFixtureValidator(
                hotkey: "5Dy6TucyF3Jg3fVonT378Jdooi5HoZ1N3MenhQrygUp3NW5j",
                coldkey: "5DTzudcua38Pv89L8fhsQPi2Qgg611RZYMwBE1VxYFytwbEm",
                identityName: "   ",
                stakeName: nil,
                take: 13107,
                alphaStake: 45300,
                rootStake: 0,
                validatorTrust: "0.7715",
                reportedRate: "9.1005",
                rootSeat: nil
            ),
            BittensorApiFixtureValidator(
                hotkey: "5GyRo9tncrKDtik7ycMKXzyrQKMRYJLn4nNuATj55xAjf7uV",
                coldkey: "5ELTtYuWcUi4HG6FqGwpY4WhDbzMLos5LVe2TBZvNEiDqL5J",
                identityName: "Halcyon Pool",
                stakeName: "Halcyon Pool",
                take: 7864,
                alphaStake: 176_800,
                rootStake: 33000,
                validatorTrust: "0.8190",
                reportedRate: "18.6653",
                rootSeat: BittensorApiFixtureRootSeat(uid: 40, hasPermit: true)
            )
        ]
    }
#endif
