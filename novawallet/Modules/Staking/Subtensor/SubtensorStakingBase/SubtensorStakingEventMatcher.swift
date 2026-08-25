import Foundation
import SubstrateSdk

struct SubtensorStakingEventMatcher: ExtrinsicEventsMatching {
    func match(event: Event, using codingFactory: RuntimeCoderFactoryProtocol) -> Bool {
        let metadata = codingFactory.metadata

        return metadata.eventMatches(event, path: SubtensorStakingPallet.stakeAddedEventPath) ||
            metadata.eventMatches(event, path: SubtensorStakingPallet.stakeRemovedEventPath) ||
            metadata.eventMatches(event, path: SubtensorStakingPallet.rootClaimedEventPath)
    }
}

enum SubtensorExecutedOutcomeParser {
    static func parseOutcome(
        from events: [Event],
        codingFactory: RuntimeCoderFactoryProtocol
    ) -> SubtensorExecutedOutcome? {
        let metadata = codingFactory.metadata
        let context = codingFactory.createRuntimeJsonContext()

        // the dispatch's own event is emitted after any pre-dispatch fee-in-alpha
        // StakeRemoved, so the last match carries the executed amount
        for event in events.reversed() {
            if
                metadata.eventMatches(event, path: SubtensorStakingPallet.stakeAddedEventPath),
                let added = try? event.params.map(
                    to: SubtensorStakingPallet.StakeAddedEvent.self,
                    with: context.toRawContext()
                ) {
                return .staked(tao: added.tao)
            }

            if
                metadata.eventMatches(event, path: SubtensorStakingPallet.stakeRemovedEventPath),
                let removed = try? event.params.map(
                    to: SubtensorStakingPallet.StakeRemovedEvent.self,
                    with: context.toRawContext()
                ) {
                return .unstaked(tao: removed.tao)
            }

            if
                metadata.eventMatches(event, path: SubtensorStakingPallet.rootClaimedEventPath),
                let claimed = try? event.params.map(
                    to: SubtensorStakingPallet.RootClaimedEvent.self,
                    with: context.toRawContext()
                ) {
                return .claimed(tao: claimed.tao)
            }
        }

        return nil
    }
}
