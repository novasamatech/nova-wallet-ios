import Foundation
import Operation_iOS

struct ResolvedValidatorEra: Equatable, Hashable {
    let validator: AccountId
    let era: Staking.EraIndex
}

protocol PayoutValidatorsFactoryProtocol {
    func createResolutionOperation(
        for address: AccountAddress,
        eraRangeClosure: @escaping () throws -> Staking.EraRange
    ) -> CompoundOperationWrapper<Set<ResolvedValidatorEra>>
}
