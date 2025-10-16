import Foundation
import Foundation_iOS

extension FormattedCall.Batch.BatchType {
    var shortDescription: LocalizableResource<String> {
        .init {
            switch self {
            case .batch:
                R.string(preferredLanguages: $0.rLanguages).localizable.pushNotificationMultisigBatchBody()
            case .batchAll:
                R.string(preferredLanguages: $0.rLanguages).localizable.pushNotificationMultisigBatchAllBody()
            case .forceBatch:
                R.string(preferredLanguages: $0.rLanguages).localizable.pushNotificationMultisigForceBatchBody()
            }
        }
    }
}
