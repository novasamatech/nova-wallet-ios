import Foundation

extension UtilityPallet {
    enum BatchType {
        case batch
        case batchAll
        case forceBatch

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
    }
}
