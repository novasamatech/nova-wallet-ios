import Foundation
import Foundation_iOS

extension FormattedCall.Batch.BatchType {
    var shortDescription: LocalizableResource<String> {
        .init {
            switch self {
            case .batch:
                R.string.localizable.batchOperationDescription(
                    preferredLanguages: $0.rLanguages
                )
            case .batchAll:
                R.string.localizable.batchAllOperationDescription(
                    preferredLanguages: $0.rLanguages
                )
            case .forceBatch:
                R.string.localizable.forceBatchOperationDescription(
                    preferredLanguages: $0.rLanguages
                )
            }
        }
    }
}
