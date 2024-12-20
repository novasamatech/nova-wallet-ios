import Foundation
import SubstrateSdk

protocol SubstrateEventsRepositoryProtocol {
    func getInherentEvents(from eventRecords: [EventRecord]) -> SubstrateInherentsEvents

    func getExtrinsicsEvents(
        from block: Block,
        eventRecords: [EventRecord]
    ) -> [SubstrateExtrinsicEvents]
}

final class SubstrateEventsRepository: SubstrateEventsRepositoryProtocol {
    func getInherentEvents(from eventRecords: [EventRecord]) -> SubstrateInherentsEvents {
        .init(
            initialization: eventRecords.filter { $0.phase.isInitialization }.map(\.event),
            finalization: eventRecords.filter { $0.phase.isFinalization }.map(\.event)
        )
    }

    func getExtrinsicsEvents(from block: Block, eventRecords: [EventRecord]) -> [SubstrateExtrinsicEvents] {
        let eventsByExtrinsicIndex = eventRecords.reduce(
            into: [ExtrinsicIndex: [EventRecord]]()
        ) { accum, record in
            guard let extrinsicIndex = record.extrinsicIndex else {
                return
            }

            let currentEvents = accum[extrinsicIndex] ?? []
            accum[extrinsicIndex] = currentEvents + [record]
        }

        return block.extrinsics.enumerated().compactMap { index, hexExtrinsic in
            do {
                let data = try Data(hexString: hexExtrinsic)
                let extrinsicHash = try data.blake2b32()

                return SubstrateExtrinsicEvents(
                    extrinsicHash: extrinsicHash,
                    extrinsicData: data,
                    eventRecords: eventsByExtrinsicIndex[ExtrinsicIndex(index)] ?? []
                )

            } catch {
                return nil
            }
        }
    }
}
