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

    var fullModuleCallDescription: LocalizableResource<String> {
        .init {
            [
                path.moduleName.displayModule,
                callDescription.value(for: $0)
            ].joined(with: .colonSpace)
        }
    }

    var callDescription: LocalizableResource<String> {
        .init {
            [
                path.callName.displayCall,
                "(\(shortDescription.value(for: $0)))"
            ].joined(with: .space)
        }
    }
}
