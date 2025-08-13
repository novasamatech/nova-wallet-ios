import Foundation
import Operation_iOS

protocol ValidatorOperationFactoryProtocol {
    func allElectedOperation() -> CompoundOperationWrapper<[ElectedValidatorInfo]>
    func allSelectedOperation(
        by nomination: Staking.Nomination,
        nominatorAddress: AccountAddress
    ) -> CompoundOperationWrapper<[SelectedValidatorInfo]>

    func activeValidatorsOperation(
        for nominatorAddress: AccountAddress
    ) -> CompoundOperationWrapper<[SelectedValidatorInfo]>

    func pendingValidatorsOperation(
        for accountIds: [AccountId]
    ) -> CompoundOperationWrapper<[SelectedValidatorInfo]>

    func wannabeValidatorsOperation(
        for accountIdList: [AccountId]
    ) -> CompoundOperationWrapper<[SelectedValidatorInfo]>

    func allPreferred(
        for preferrence: PreferredValidatorsProviderModel?
    ) -> CompoundOperationWrapper<ElectedAndPrefValidators>
}
