import Foundation
@testable import novawallet
import Operation_iOS
import SubstrateSdk

final class SlashesOperationFactoryStub: SlashesOperationFactoryProtocol {
    let slashingSpans: SlashingSpans?

    init(slashingSpans: SlashingSpans?) {
        self.slashingSpans = slashingSpans
    }

    func createSlashingSpansOperationForStash(
        _: @escaping () throws -> AccountId,
        engine _: JSONRPCEngine,
        runtimeService _: RuntimeCodingServiceProtocol
    ) -> CompoundOperationWrapper<SlashingSpans?> {
        CompoundOperationWrapper.createWithResult(slashingSpans)
    }
}
