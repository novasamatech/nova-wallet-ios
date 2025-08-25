import Foundation
import Foundation_iOS

extension FormattedCall.Batch.BatchType {
    var shortDescription: LocalizableResource<String> {
        .init {
            switch self {
            case .batch:
                R.string.localizable.pushNotificationMultisigBatchBody(
                    preferredLanguages: $0.rLanguages
                )
            case .batchAll:
                R.string.localizable.pushNotificationMultisigBatchAllBody(
                    preferredLanguages: $0.rLanguages
                )
            case .forceBatch:
                R.string.localizable.pushNotificationMultisigForceBatchBody(
                    preferredLanguages: $0.rLanguages
                )
            }
        }
    }
}
