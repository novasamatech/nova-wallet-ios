import XCTest
@testable import novawallet
import BigInt

enum GovernanceUnlocksTestBuilding {
    struct Test {
        let givenSchedule: GovernanceUnlockSchedule?
        let expectSchedule: UnlockScheduleTestBuilding.ScheduleResult?
    }

    struct ReferendumDef {
        enum ReferendumType {
            case ongoing(since: BlockNumber)
        }

        let index: ReferendumIdLocal
        let trackId: Referenda.TrackId
        let type: ReferendumType
    }

    struct TrackDef {
        let trackId: Referenda.TrackId
        let decisionPeriod: Moment
        let confirmPeriod: Moment
    }

    @resultBuilder
    enum TestBuilder {
        static func buildBlock(_ givenSchedule: GovernanceUnlockSchedule) -> Test {
            .init(givenSchedule: givenSchedule, expectSchedule: nil)
        }

        static func buildBlock(_ expectSchedule: UnlockScheduleTestBuilding.ScheduleResult) -> Test {
            .init(givenSchedule: nil, expectSchedule: expectSchedule)
        }

        static func buildBlock(_ components: Test...) -> Test {
            let initTest = Test(givenSchedule: nil, expectSchedule: nil)

            return components.reduce(initTest) { accum, test in
                let given = test.givenSchedule ?? accum.givenSchedule
                let expect = test.expectSchedule ?? accum.expectSchedule

                return .init(givenSchedule: given, expectSchedule: expect)
            }
        }
    }

    static func run(atBlock block: BlockNumber, @TestBuilder _ builder: () -> Test) {
        let test = builder()

        guard let schedule = test.givenSchedule else {
            XCTFail("Give schedule is not provided")
            return
        }

        guard let expect = test.expectSchedule else {
            XCTFail("Expected result is not provided")
            return
        }

        XCTAssertEqual(schedule.availableUnlock(at: block), expect.available)
        XCTAssertEqual(schedule.remainingLocks(after: block), expect.remaining)
    }

    static func given(
        tracksDef: [TrackDef] = [],
        referendumsDef: [ReferendumDef] = [],
        @TrackTestBuilding.TrackVotingBuilder _ content: () -> TrackTestBuilding.VotingWithReferendumUnlock
    ) -> Test {
        let compoundVoting = content()

        let tracksVoting = compoundVoting.votingDistribution
        let refendumsUnlock = compoundVoting.referendumsUnlock

        let initReferendums = [ReferendumIdLocal: GovUnlockReferendumProtocol]()
        let referendums = tracksVoting.votes.tracksByReferendums().keys.reduce(into: initReferendums) { accum, referendumId in
            let referendum = prepareReferendumInfo(
                for: referendumId,
                given: referendumsDef,
                referendumsUnlock: refendumsUnlock
            )

            accum[referendumId] = Gov2UnlockReferendum(referendumInfo: referendum)
        }

        let additions = GovUnlockCalculationInfo(
            decisionPeriods: prepareDecisionPeriods(from: tracksDef),
            confirmPeriods: prepareConfirmPeriods(from: tracksDef),
            undecidingTimeout: 0,
            voteLockingPeriod: 0
        )

        let schedule = GovUnlocksCalculator().createUnlocksSchedule(
            for: tracksVoting,
            referendums: referendums,
            additionalInfo: additions
        )

        return .init(givenSchedule: schedule, expectSchedule: nil)
    }

    static func expect(
        @UnlockScheduleTestBuilding.ScheduleResultBuilder _ builder: () -> UnlockScheduleTestBuilding.ScheduleResult
    ) -> Test {
        let result = builder()

        return .init(givenSchedule: nil, expectSchedule: result)
    }

    private static func prepareReferendumInfo(
        for referendumId: ReferendumIdLocal,
        given definitions: [ReferendumDef],
        referendumsUnlock: [ReferendumIdLocal: BlockNumber]
    ) -> ReferendumInfo {
        let deposit = Referenda.Deposit(who: AccountId.zeroAccountId(of: 32), amount: BigUInt(0))

        guard let definition = definitions.first(where: { $0.index == referendumId }) else {
            return .approved(
                .init(
                    since: referendumsUnlock[referendumId] ?? 0,
                    submissionDeposit: deposit,
                    decisionDeposit: deposit
                )
            )
        }

        switch definition.type {
        case let .ongoing(since):
            return .ongoing(
                .init(
                    track: definition.trackId,
                    proposal: .legacy(hash: Data.random(of: 32)!),
                    enactment: .unknown,
                    submitted: since,
                    submissionDeposit: deposit,
                    decisionDeposit: deposit,
                    deciding: .some(.init(since: since)),
                    tally: .init(ayes: 0, nays: 0, support: 0),
                    inQueue: false
                )
            )
        }
    }

    private static func prepareDecisionPeriods(from tracksDef: [TrackDef]) -> [Referenda.TrackId: Moment] {
        tracksDef.reduce(into: [Referenda.TrackId: Moment]()) { $0[$1.trackId] = $1.decisionPeriod }
    }

    private static func prepareConfirmPeriods(from tracksDef: [TrackDef]) -> [Referenda.TrackId: Moment] {
        tracksDef.reduce(into: [Referenda.TrackId: Moment]()) { $0[$1.trackId] = $1.confirmPeriod }
    }
}

enum UnlockScheduleTestBuilding {
    @resultBuilder
    enum ClaimActionBuilder {
        static func buildBlock(_ components: GovernanceUnlockSchedule.Action...) -> Set<GovernanceUnlockSchedule.Action> {
            Set(components)
        }
    }

    @resultBuilder
    enum ItemBuilder {
        static func buildBlock(_ components: GovernanceUnlockSchedule.Item...) -> [GovernanceUnlockSchedule.Item] {
            Array(components)
        }
    }

    struct ScheduleResult {
        let available: GovernanceUnlockSchedule.Claimable
        let remaining: [GovernanceUnlockSchedule.Item]

        static func availableItem(
            amount: BigUInt,
            @ClaimActionBuilder _ actionsBlock: () -> Set<GovernanceUnlockSchedule.Action>
        ) -> ScheduleResult {
            .init(
                available:
                .init(
                    amount: amount,
                    actions: actionsBlock()
                ),
                remaining: []
            )
        }

        static func remainingItems(@ItemBuilder _ block: () -> [GovernanceUnlockSchedule.Item]) -> ScheduleResult {
            .init(available: .empty(), remaining: block())
        }
    }

    @resultBuilder
    enum ScheduleResultBuilder {
        static func buildBlock(_ components: ScheduleResult...) -> ScheduleResult {
            let initResult = ScheduleResult(available: .empty(), remaining: [])

            return components.reduce(initResult) { accum, schedule in
                let available = !schedule.available.isEmpty ? schedule.available : accum.available
                let remaining = accum.remaining + schedule.remaining

                return .init(available: available, remaining: remaining)
            }
        }
    }

    static func unlock(
        amount: BigUInt,
        atBlock: BlockNumber,
        @ClaimActionBuilder _ actionsBlock: () -> Set<GovernanceUnlockSchedule.Action>
    ) -> GovernanceUnlockSchedule.Item {
        let actions = actionsBlock()

        return .init(amount: amount, unlockWhen: .unlockAt(atBlock), actions: actions)
    }

    static func unlockAfterUndelegate(amount: BigUInt) -> GovernanceUnlockSchedule.Item {
        .init(amount: amount, unlockWhen: .afterUndelegate, actions: Set())
    }
}

enum TrackTestBuilding {
    struct VotingWithReferendumUnlock {
        let votingDistribution: ReferendumTracksVotingDistribution
        let referendumsUnlock: [ReferendumIdLocal: BlockNumber]
    }

    @resultBuilder
    enum TrackVotingBuilder {
        static func buildBlock(_ components: Voting...) -> VotingWithReferendumUnlock {
            let initValue = ReferendumTracksVotingDistribution(
                votes: .init(maxVotesPerTrack: 512),
                trackLocks: []
            )

            let votingDistribution = components.reduce(initValue) { accum, voting in
                var accountVoting = accum.votes

                for vote in voting.votes {
                    switch vote.type {
                    case let .standard(amount, conviction, isAye):
                        accountVoting = accountVoting
                            .addingReferendum(vote.referendum, track: voting.trackId)
                            .addingVote(
                                .standard(
                                    .init(
                                        vote: .init(aye: isAye, conviction: conviction),
                                        balance: amount
                                    )
                                ),
                                referendumId: vote.referendum
                            )
                    case let .abstain(amount):
                        accountVoting = accountVoting
                            .addingReferendum(vote.referendum, track: voting.trackId)
                            .addingVote(
                                .splitAbstain(
                                    .init(
                                        aye: 0,
                                        nay: 0,
                                        abstain: amount
                                    )
                                ),
                                referendumId: vote.referendum
                            )
                    }
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

            let referendumsUnlock = components.reduce(into: [ReferendumIdLocal: BlockNumber]()) { accum, voting in
                for vote in voting.votes {
                    accum[vote.referendum] = vote.unlockAt
                }
            }

            return .init(votingDistribution: votingDistribution, referendumsUnlock: referendumsUnlock)
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

    enum VoteType {
        case standard(amount: BigUInt, conviction: ConvictionVoting.Conviction, isAye: Bool)
        case abstain(amount: BigUInt)
    }

    struct Vote {
        let referendum: ReferendumIdLocal
        let unlockAt: BlockNumber
        let type: VoteType

        static func standard(
            referendum: ReferendumIdLocal,
            amount: BigUInt,
            unlockAt: BlockNumber,
            conviction: ConvictionVoting.Conviction = .locked1x,
            isAye: Bool = true
        ) -> Vote {
            Vote(
                referendum: referendum,
                unlockAt: unlockAt,
                type: .standard(amount: amount, conviction: conviction, isAye: isAye)
            )
        }

        static func abstain(
            referendum: ReferendumIdLocal,
            amount: BigUInt,
            unlockAt: BlockNumber
        ) -> Vote {
            Vote(referendum: referendum, unlockAt: unlockAt, type: .abstain(amount: amount))
        }
    }

    @resultBuilder
    enum VoteBuilder {
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

        static func delegating(
            amount: BigUInt,
            conviction: ConvictionVoting.Conviction = .none,
            target: AccountId = AccountId.zeroAccountId(of: 32)
        ) -> VotingParams {
            .init(
                locked: 0,
                votes: [],
                prior: .notExisting,
                delegating: .init(
                    balance: amount, target: target, conviction: conviction
                )
            )
        }
    }

    @resultBuilder
    enum VotingParamsBuilder {
        static func buildBlock(_ components: VotingParams...) -> VotingParams {
            let initValue = VotingParams(locked: 0, votes: [], prior: .notExisting, delegating: nil)

            return components.reduce(initValue) { accum, param in
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
        @TrackVotingBuilder _ builder: () -> VotingWithReferendumUnlock
    ) -> VotingWithReferendumUnlock {
        builder()
    }
}
