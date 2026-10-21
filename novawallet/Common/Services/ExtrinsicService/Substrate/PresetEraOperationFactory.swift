import Foundation
import Operation_iOS
import SubstrateSdk

final class PresetEraOperationFactory {
    let parameters: ExtrinsicEraParameters

    init(parameters: ExtrinsicEraParameters) {
        self.parameters = parameters
    }
}

extension PresetEraOperationFactory: ExtrinsicEraOperationFactoryProtocol {
    func createOperation(
        from _: JSONRPCEngine,
        runtimeService _: RuntimeCodingServiceProtocol
    ) -> CompoundOperationWrapper<ExtrinsicEraParameters> {
        .createWithResult(parameters)
    }
}
