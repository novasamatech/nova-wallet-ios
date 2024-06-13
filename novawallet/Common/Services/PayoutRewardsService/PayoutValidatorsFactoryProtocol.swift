import Foundation
import Operation_iOS

struct ResolvedValidatorEra: Equatable, Hashable {
    let validator: AccountId
    let era: EraIndex
}

protocol PayoutValidatorsFactoryProtocol {
    func createResolutionOperation(
        for address: AccountAddress,
        eraRangeClosure: @escaping () throws -> EraRange
    ) -> CompoundOperationWrapper<Set<ResolvedValidatorEra>>
}
