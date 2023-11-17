import Foundation
import SubstrateSdk

extension ExtrinsicProcessor {
    func findFeeInCustomAsset(
        in events: [EventRecord],
        codingFactory: RuntimeCoderFactoryProtocol
    ) throws -> AssetTxPaymentPallet.AssetTxFeePaid? {
        let context = codingFactory.createRuntimeJsonContext()
        let metadata = codingFactory.metadata

        let optFeeRecord = events.first { record in
            guard let eventPath = metadata.createEventCodingPath(from: record.event) else {
                return false
            }

            return eventPath == AssetTxPaymentPallet.assetTxFeePaidEvent
        }

        return try optFeeRecord?.event.params.map(
            to: AssetTxPaymentPallet.AssetTxFeePaid.self,
            with: context.toRawContext()
        )
    }
}
