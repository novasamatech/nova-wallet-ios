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
        let calls: [AnyRuntimeCall]
    }

    struct DispatchAs<T: Codable>: Codable {
        enum CodingKeys: String, CodingKey {
            case asOrigin = "as_origin"
            case call
        }

        let asOrigin: RuntimeCallOrigin
        let call: RuntimeCall<T>

        func runtimeCall() -> RuntimeCall<Self> {
            RuntimeCall(
                moduleName: UtilityPallet.name,
                callName: "dispatch_as",
                args: self
            )
        }
    }
}
