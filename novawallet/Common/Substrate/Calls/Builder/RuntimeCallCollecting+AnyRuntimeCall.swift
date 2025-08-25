import Foundation
import SubstrateSdk

extension RuntimeCallCollecting {
    func toAnyRuntimeCall(with context: RuntimeJsonContext) throws -> AnyRuntimeCall {
        let builder = RuntimeCallBuilder(context: context)
        return try addingToCall(builder: builder, toEnd: true).build()
    }
}
