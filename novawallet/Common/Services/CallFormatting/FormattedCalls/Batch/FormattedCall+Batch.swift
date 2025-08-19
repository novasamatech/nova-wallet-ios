import Foundation
import Foundation_iOS

extension FormattedCall {
    struct Batch {
        enum BatchType {
            case batch
            case batchAll
            case forceBatch
        }
        let type: BatchType
    }
}

extension FormattedCall.Batch.BatchType {
    var path: CallCodingPath {
        switch self {
        case .batch:
            UtilityPallet.batchPath
        case .batchAll:
            UtilityPallet.batchAllPath
        case .forceBatch:
            UtilityPallet.forceBatchPath
        }
    }
    
    lazy var callDescription = LocalizableResource {
        [
            path.callName,
            "(\(shortDescription.value(for: $0)))"
        ].joined(with: .space)
    }
    
    lazy var fullModuleCallDescription = LocalizableResource {
        [
            [
                path.moduleName,
                path.callName
            ].joined(with: .colonSpace),
            
            "(\(shortDescription.value(for: $0)))"
        ].joined(with: .space)
    }
    
    private lazy var shortDescription = LocalizableResource<String> {
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
