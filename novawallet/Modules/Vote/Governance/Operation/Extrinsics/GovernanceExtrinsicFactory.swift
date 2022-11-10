import Foundation
import SubstrateSdk

class GovernanceExtrinsicFactory {
    func appendCalls<C: RuntimeCallable>(
        _ calls: [C],
        builder: ExtrinsicBuilderProtocol
    ) throws -> ExtrinsicBuilderProtocol {
        try calls.reduce(builder) { try $0.adding(call: $1) }
    }
}
