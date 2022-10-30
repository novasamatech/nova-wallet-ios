import Foundation
import BigInt
@testable import novawallet

enum GovernanceTestBuilding {
    static func given(
        currentBlock: BlockNumber,
        @TrackTestBuilding.TrackVotingBuilder _ content: () -> ReferendumTracksVotingDistribution
    ) -> GovernanceUnlockSchedule {
        let tracksVoting = content()

        let initReferendums = [ReferendumIdLocal: ReferendumInfo]()
        let referendums = tracksVoting.votes.tracksByReferendums().keys.reduce(into: initReferendums) { (accum, referendumId) in
            let deposit = Referenda.Deposit(who: AccountId.empty, amount: BigUInt(0))
            accum[referendumId] = ReferendumInfo.approved(
                .init(
                    since: currentBlock,
                    submissionDeposit: deposit,
                    decisionDeposit: deposit
                )
            )
        }

        

        Gov2UnlocksCalculator().createUnlocksSchedule(
            for: tracksVoting,
            referendums: referendums,
            additionalInfo: <#T##GovUnlockCalculationInfo#>)
    }
}

enum TrackTestBuilding {
    @resultBuilder
    struct TrackVotingBuilder {
        static func buildBlock(_ components: Voting...) -> ReferendumTracksVotingDistribution {
            let initValue = ReferendumTracksVotingDistribution(
                votes: .init(maxVotesPerTrack: 512),
                trackLocks: []
            )

            return components.reduce(initValue) { (accum, voting) in
                var accountVoting = accum.votes

                for vote in voting.votes {
                    accountVoting = accountVoting
                        .addingReferendum(vote.referendum, track: voting.trackId)
                        .addingVote(
                            .standard(
                                .init(
                                    vote: .init(aye: vote.isAye, conviction: vote.conviction),
                                    balance: vote.balance
                                )
                            ),
                            referendumId: vote.referendum
                        )
                }

                if voting.prior.exists {
                    accountVoting = accountVoting.addingPriorLock(voting.prior, track: voting.trackId)
                }

                if let delegating = voting.delegating {
                    accountVoting = accountVoting.addingDelegating(delegating, trackId: voting.trackId)
                }

                let trackLock = ConvictionVoting.ClassLock(
                    trackId: Referenda.TrackId(voting.trackId),
                    amount: voting.locked
                )

                return ReferendumTracksVotingDistribution(
                    votes: accountVoting,
                    trackLocks: accum.trackLocks + [trackLock]
                )
            }
        }
    }

    struct Voting {
        let trackId: TrackIdLocal
        let locked: BigUInt
        let votes: [Vote]
        let prior: ConvictionVoting.PriorLock
        let delegating: ReferendumDelegatingLocal?
    }

    typealias Locked = BigUInt

    struct Vote {
        let referendum: ReferendumIdLocal
        let balance: BigUInt
        let conviction: ConvictionVoting.Conviction
        let isAye: Bool

        init(
            referendum: ReferendumIdLocal,
            balance: BigUInt,
            conviction: ConvictionVoting.Conviction = .locked1x,
            isAye: Bool = true
        ) {
            self.referendum = referendum
            self.balance = balance
            self.conviction = conviction
            self.isAye = isAye
        }
    }

    @resultBuilder
    struct VoteBuilder {
        static func buildBlock(_ components: Vote...) -> [Vote] {
            Array(components)
        }
    }

    struct VotingParams {
        let locked: Locked
        let votes: [Vote]
        let prior: ConvictionVoting.PriorLock
        let delegating: ReferendumDelegatingLocal?

        static func locked(_ amount: BigUInt) -> VotingParams {
            VotingParams(locked: amount, votes: [], prior: .notExisting, delegating: nil)
        }

        static func votes(@VoteBuilder _ content: () -> [Vote]) -> VotingParams {
            VotingParams(locked: 0, votes: content(), prior: .notExisting, delegating: nil)
        }

        static func prior(amount: BigUInt, unlockAt: BlockNumber) -> VotingParams {
            VotingParams(locked: 0, votes: [], prior: .init(unlockAt: unlockAt, amount: amount), delegating: nil)
        }
    }

    @resultBuilder
    class VotingParamsBuilder {
        static func buildBlock(_ components: VotingParams...) -> VotingParams {
            let initValue = VotingParams(locked: 0, votes: [], prior: .notExisting, delegating: nil)

            return components.reduce(initValue) { (accum, param) in
                VotingParams(
                    locked: accum.locked + param.locked,
                    votes: accum.votes + param.votes,
                    prior: param.prior.exists ? param.prior : accum.prior,
                    delegating: param.delegating != nil ? param.delegating : accum.delegating
                )
            }
        }
    }

    static func track(_ trackId: TrackIdLocal, @VotingParamsBuilder _ builder: () -> VotingParams) -> Voting {
        let params = builder()

        return Voting(
            trackId: trackId,
            locked: params.locked,
            votes: params.votes,
            prior: params.prior,
            delegating: params.delegating
        )
    }

    static func tracksVoting(
        @TrackVotingBuilder _ builder: () -> ReferendumTracksVotingDistribution
    ) -> ReferendumTracksVotingDistribution {
        builder()
    }
}

let tracks = TrackTestBuilding.tracksVoting {
    TrackTestBuilding.track(0) {
        TrackTestBuilding.VotingParams.locked(10)

        TrackTestBuilding.VotingParams.prior(amount: 10, unlockAt: 100)

        TrackTestBuilding.VotingParams.votes {
            TrackTestBuilding.Vote(referendum: 0, balance: 10)
        }
    }

    TrackTestBuilding.track(1) {
        TrackTestBuilding.VotingParams.locked(15)

        TrackTestBuilding.VotingParams.prior(amount: 10, unlockAt: 100)

        TrackTestBuilding.VotingParams.votes {
            TrackTestBuilding.Vote(referendum: 0, balance: 10)
        }
    }
}
