import Foundation
import SubstrateSdk

extension RuntimeCall {
    init(path: CallCodingPath, args: T) {
        self.init(moduleName: path.moduleName, callName: path.callName, args: args)
    }

    var path: CallCodingPath {
        CallCodingPath(moduleName: moduleName, callName: callName)
    }

    func anyRuntimeCall(with context: RuntimeJsonContext?) throws -> AnyRuntimeCall {
        let anyArgs = try args.toScaleCompatibleJSON(with: context?.toRawContext())

        return AnyRuntimeCall(
            moduleName: moduleName,
            callName: callName,
            args: anyArgs
        )
    }
}

extension RuntimeCall where T == NoRuntimeArgs {
    init(path: CallCodingPath) {
        self.init(moduleName: path.moduleName, callName: path.callName)
    }
}

typealias AnyRuntimeCall = RuntimeCall<JSON>

extension AnyRuntimeCall {
    init<A: Codable>(path: CallCodingPath, args: A, context: RuntimeJsonContext?) throws {
        let anyArgs = try args.toScaleCompatibleJSON(with: context?.toRawContext())
        self.init(moduleName: path.moduleName, callName: path.callName, args: anyArgs)
    }
}
