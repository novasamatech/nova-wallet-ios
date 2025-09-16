import Foundation
@testable import novawallet
import Operation_iOS

final class MockPreferredValidatorsProvider {
    let model: PreferredValidatorsProviderModel?

    init(model: PreferredValidatorsProviderModel? = nil) {
        self.model = model
    }
}

extension MockPreferredValidatorsProvider: PreferredValidatorsProviding {
    func createPreferredValidatorsWrapper(
        for _: ChainModel
    ) -> CompoundOperationWrapper<PreferredValidatorsProviderModel?> {
        CompoundOperationWrapper.createWithResult(model)
    }
}
