import Foundation
import Operation_iOS
@testable import NovaAnalytics

final class AnalyticsEventQueueStub: AnalyticsEventQueueProtocol {
    private let recordedEvents = Locked<[AnalyticsPendingEvent]>([])
    private let recordedDrops = Locked<[String]>([])

    var events: [AnalyticsPendingEvent] {
        get { recordedEvents.value }
        set { recordedEvents.update { $0 = newValue } }
    }

    var droppedIds: [String] { recordedDrops.value }

    func enqueueWrapper(
        name: String,
        timestamp: Date,
        payload: Data,
        consentEpoch: Int
    ) -> CompoundOperationWrapper<Void> {
        CompoundOperationWrapper(targetOperation: ClosureOperation { [self] in
            recordedEvents.update { events in
                events.append(AnalyticsPendingEvent(
                    identifier: UUID().uuidString,
                    eventId: UUID().uuidString.lowercased(),
                    sequence: Int64(events.count),
                    name: name,
                    timestamp: timestamp,
                    payload: payload,
                    consentEpoch: consentEpoch
                ))
            }
        })
    }

    func peekWrapper(count: Int) -> CompoundOperationWrapper<[AnalyticsPendingEvent]> {
        CompoundOperationWrapper(targetOperation: ClosureOperation { [self] in
            Array(events.prefix(count))
        })
    }

    func dropOperation(ids: [String]) -> BaseOperation<Void> {
        ClosureOperation { [self] in
            recordedDrops.update { $0.append(contentsOf: ids) }
            recordedEvents.update { $0.removeAll { ids.contains($0.identifier) } }
        }
    }

    func countOperation() -> BaseOperation<Int> {
        ClosureOperation { [self] in events.count }
    }

    func clearOperation() -> BaseOperation<Void> {
        ClosureOperation { [self] in events = [] }
    }
}
