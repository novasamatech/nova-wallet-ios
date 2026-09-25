import Foundation
import BigInt
import Operation_iOS

#if DEBUG
    final class BittensorFixtureChainSnapshot {}

    extension BittensorFixtureChainSnapshot: SubtensorValidatorChainOperationFactoryProtocol {
        func createChainSnapshotWrapper(
            for query: SubtensorValidatorChainQuery
        ) -> CompoundOperationWrapper<SubtensorValidatorChainSnapshot> {
            let operation = ClosureOperation<SubtensorValidatorChainSnapshot> {
                try Self.snapshot(for: query)
            }

            return CompoundOperationWrapper(targetOperation: operation)
        }

        func createIdentitiesWrapper(
            for hotkeys: [AccountId]
        ) -> CompoundOperationWrapper<[AccountId: SubtensorValidatorIdentity]> {
            let operation = ClosureOperation<[AccountId: SubtensorValidatorIdentity]> {
                let members = try Self.membersByAccountId()

                return hotkeys.reduce(into: [:]) { result, hotkey in
                    guard
                        let member = members[hotkey],
                        let name = World.validator(member).identityName?.trimmingCharacters(in: .whitespaces),
                        !name.isEmpty else {
                        return
                    }

                    result[hotkey] = SubtensorValidatorIdentity(
                        name: name,
                        url: nil,
                        githubRepo: nil,
                        image: nil,
                        discord: nil,
                        description: nil
                    )
                }
            }

            return CompoundOperationWrapper(targetOperation: operation)
        }
    }

    private extension BittensorFixtureChainSnapshot {
        typealias World = BittensorApiFixtureWorld

        static func membersByAccountId() throws -> [AccountId: World.Member] {
            try World.Member.allCases.reduce(into: [:]) { result, member in
                let accountId = try World.validator(member).hotkey.toAccountId(
                    using: .substrate(SubstrateConstants.genericAddressPrefix)
                )

                result[accountId] = member
            }
        }

        static func snapshot(for query: SubtensorValidatorChainQuery) throws -> SubtensorValidatorChainSnapshot {
            let members = try membersByAccountId()

            var uids: [SubtensorHotkeySubnet: UInt16] = [:]
            var hotkeyAlpha: [SubtensorHotkeySubnet: Balance] = [:]

            for pair in query.pairs {
                let member = members[pair.hotkey]
                let seat = member.flatMap { World.seat(of: $0, netuid: pair.netuid) }

                if let seat {
                    uids[pair] = seat.uid
                }

                if query.includesHotkeyAlpha {
                    hotkeyAlpha[pair] = stake(of: seat != nil ? member : nil, netuid: pair.netuid)
                }
            }

            var permits: [UInt16: [Bool]] = [:]
            var lastUpdates: [UInt16: [UInt64]] = [:]
            var cutoffs: [UInt16: UInt64] = [:]

            for netuid in Set(query.pairs.map(\.netuid)) {
                let vectors = self.vectors(netuid: netuid)
                let parameters = World.activityCutoffParameters(netuid: netuid)

                permits[netuid] = vectors.permits
                lastUpdates[netuid] = vectors.lastUpdates
                cutoffs[netuid] = SubtensorValidatorChainStatus.effectiveActivityCutoff(
                    factorMilli: parameters.factorMilli,
                    tempo: parameters.tempo
                )
            }

            let takes = Set(query.pairs.map(\.hotkey)).reduce(into: [AccountId: UInt16]()) { result, hotkey in
                result[hotkey] = members[hotkey].map { World.validator($0).take } ?? World.defaultDelegateTake
            }

            return SubtensorValidatorChainSnapshot(
                blockHash: World.blockHash,
                blockNumber: BlockNumber(World.headBlock),
                uids: uids,
                permits: permits,
                lastUpdates: lastUpdates,
                effectiveActivityCutoffs: cutoffs,
                takes: takes,
                hotkeyAlpha: hotkeyAlpha
            )
        }

        static func stake(of member: World.Member?, netuid: UInt16) -> Balance {
            guard let member else {
                return 0
            }

            let validator = World.validator(member)
            let units = netuid == World.rootNetuid ? validator.rootStake : validator.alphaStake

            return Balance(units) * Balance(World.alphaUnit)
        }

        static func vectors(netuid: UInt16) -> (permits: [Bool], lastUpdates: [UInt64]) {
            let length: Int
            let unseatedLastUpdate: UInt64

            if netuid == World.rootNetuid {
                length = World.rootVectorLength
                unseatedLastUpdate = World.frozenRootLastUpdate
            } else if World.subnet(netuid: netuid) != nil {
                length = World.subnetVectorLength
                unseatedLastUpdate = World.unseatedSlotLastUpdate
            } else {
                return ([], [])
            }

            var permits = [Bool](repeating: false, count: length)
            var lastUpdates = [UInt64](repeating: unseatedLastUpdate, count: length)

            for member in World.Member.allCases {
                guard let seat = World.seat(of: member, netuid: netuid) else {
                    continue
                }

                permits[Int(seat.uid)] = seat.hasPermit
                lastUpdates[Int(seat.uid)] = seat.lastUpdate
            }

            return (permits, lastUpdates)
        }
    }
#endif
