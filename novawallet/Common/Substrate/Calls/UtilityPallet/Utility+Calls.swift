import Foundation
import SubstrateSdk

extension UtilityPallet {
    static var batchPath: CallCodingPath {
        CallCodingPath(moduleName: name, callName: "batch")
    }

    static var batchAllPath: CallCodingPath {
        CallCodingPath(moduleName: name, callName: "batch_all")
    }

    static var forceBatchPath: CallCodingPath {
        CallCodingPath(moduleName: name, callName: "force_batch")
    }

    static func isBatch(path: CallCodingPath) -> Bool {
        [batchPath, batchAllPath, forceBatchPath].contains(path)
    }

    struct Call: Codable {
        let calls: [RuntimeCall<JSON>]
    }
}
