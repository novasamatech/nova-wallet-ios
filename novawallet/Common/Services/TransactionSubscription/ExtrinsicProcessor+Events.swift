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
            metadata.createEventCodingPath(from: record.event) == BalancesPallet.balancesTransfer
        }.map { eventRecord in
            try eventRecord.event.params.map(to: BalancesPallet.TransferEvent.self, with: context.toRawContext())
        }?.amount
    }

    func matchOrmlTransferAmount(
        from eventRecords: [EventRecord],
        metadata: RuntimeMetadataProtocol,
        context: RuntimeJsonContext
    ) throws -> BigUInt? {
        let eventPaths: [EventCodingPath] = [.tokensTransfer, .currenciesTransferred]
        return try eventRecords.first { record in
            let isTransferAll = metadata.createEventCodingPath(from: record.event).map { eventPaths.contains($0) }
            return isTransferAll == true
        }.map { eventRecord in
            try eventRecord.event.params.map(to: TokenTransferedEvent.self, with: context.toRawContext())
        }?.amount
    }
}
