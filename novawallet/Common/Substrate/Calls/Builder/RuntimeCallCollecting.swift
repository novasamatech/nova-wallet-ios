import Foundation
import SubstrateSdk

protocol RuntimeCallCollecting {
    var callPath: CallCodingPath { get }

    func addingToExtrinsic(builder: ExtrinsicBuilderProtocol) throws -> ExtrinsicBuilderProtocol
    func addingToCall(builder: RuntimeCallBuilding) throws -> RuntimeCallBuilding
}

struct RuntimeCallCollector<T: Codable> {
    let call: RuntimeCall<T>
}

extension RuntimeCallCollector: RuntimeCallCollecting {
    var callPath: CallCodingPath {
        CallCodingPath(moduleName: call.moduleName, callName: call.callName)
    }

    func addingToExtrinsic(builder: ExtrinsicBuilderProtocol) throws -> ExtrinsicBuilderProtocol {
        try builder.adding(call: call)
    }

    func addingToCall(builder: RuntimeCallBuilding) throws -> RuntimeCallBuilding {
        try builder.addingLast(call)
    }
}
