import Foundation
@testable import novawallet
import Operation_iOS
import SubstrateSdk

final class SlashesOperationFactoryStub: SlashesOperationFactoryProtocol {
    let slashingSpans: Staking.SlashingSpans?
    let unappliedSlashes: RelayStkUnappliedSlashes

    init(slashingSpans: Staking.SlashingSpans?, unappliedSlashes: RelayStkUnappliedSlashes) {
        self.slashingSpans = slashingSpans
        self.unappliedSlashes = unappliedSlashes
    }

    func createSlashingSpansOperationForStash(
        _: @escaping () throws -> AccountId,
        engine _: JSONRPCEngine,
        runtimeService _: RuntimeCodingServiceProtocol
    ) -> CompoundOperationWrapper<Staking.SlashingSpans?> {
        CompoundOperationWrapper.createWithResult(slashingSpans)
    }

    func createUnappliedSlashesWrapper(
        erasClosure: @escaping () throws -> [Staking.EraIndex]?,
        engine _: JSONRPCEngine,
        runtimeService _: RuntimeCodingServiceProtocol
    ) -> CompoundOperationWrapper<RelayStkUnappliedSlashes> {
        let operation = ClosureOperation<RelayStkUnappliedSlashes> {
            if let eras = try erasClosure() {
                let erasSet = Set(eras)
                return self.unappliedSlashes.filter { erasSet.contains($0.key) }
            } else {
                return self.unappliedSlashes
            }
        }

        return CompoundOperationWrapper(targetOperation: operation)
    }
}
