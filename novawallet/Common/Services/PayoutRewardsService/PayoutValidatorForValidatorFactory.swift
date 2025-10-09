import Foundation
import Operation_iOS
import NovaCrypto

final class PayoutValidatorsForValidatorFactory: PayoutValidatorsFactoryProtocol {
    func createResolutionOperation(
        for address: AccountAddress,
        eraRangeClosure: @escaping () throws -> Staking.EraRange
    ) -> CompoundOperationWrapper<Set<ResolvedValidatorEra>> {
        let operation = ClosureOperation<Set<ResolvedValidatorEra>> {
            let accountId = try address.toAccountId()
            let eraRange = try eraRangeClosure()
            let validators = (eraRange.start ... eraRange.end).map {
                ResolvedValidatorEra(validator: accountId, era: $0)
            }
            return Set(validators)
        }

        return CompoundOperationWrapper(targetOperation: operation)
    }
}
