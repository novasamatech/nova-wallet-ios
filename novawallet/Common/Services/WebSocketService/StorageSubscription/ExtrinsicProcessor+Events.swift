import Foundation
import BigInt
import SubstrateSdk

extension ExtrinsicProcessor {
    func matchBalancesTransferAmount(
        from eventRecords: [EventRecord],
        metadata: RuntimeMetadataProtocol,
        context: RuntimeJsonContext
    ) throws -> BigUInt? {
        try eventRecords.first { record in
            if
                let eventPath = metadata.createEventCodingPath(from: record.event),
                eventPath == EventCodingPath.balancesTransfer {
                return true
            } else {
                return false
            }
        }.map { eventRecord in
            try eventRecord.event.params.map(to: BalancesTransferEvent.self, with: context.toRawContext())
        }?.amount
    }

    func matchOrmlTransferAmount(
        from eventRecords: [EventRecord],
        metadata: RuntimeMetadataProtocol,
        context: RuntimeJsonContext
    ) throws -> BigUInt? {
        let eventPaths: [EventCodingPath] = [.tokensTransfer, .currenciesTransfer]
        return try eventRecords.first { record in
            if
                let eventPath = metadata.createEventCodingPath(from: record.event),
                eventPaths.contains(eventPath) {
                return true
            } else {
                return false
            }
        }.map { eventRecord in
            try eventRecord.event.params.map(to: TokenTransferedEvent.self, with: context.toRawContext())
        }?.amount
    }
}
