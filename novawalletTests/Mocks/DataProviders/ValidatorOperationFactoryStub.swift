@testable import novawallet
import Operation_iOS

class ValidatorOperationFactoryStub: ValidatorOperationFactoryProtocol {
    private let electedValidatorList: [ElectedValidatorInfo]
    private let selectedValidatorList: [SelectedValidatorInfo]

    init(
        electedValidatorList: [ElectedValidatorInfo] = [],
        selectedValidatorList: [SelectedValidatorInfo] = []
    ) {
        self.electedValidatorList = electedValidatorList
        self.selectedValidatorList = selectedValidatorList
    }

    func allElectedOperation() -> CompoundOperationWrapper<[ElectedValidatorInfo]> {
        CompoundOperationWrapper.createWithResult(electedValidatorList)
    }

    func allSelectedOperation(by _: Nomination, nominatorAddress _: AccountAddress) -> CompoundOperationWrapper<[SelectedValidatorInfo]> {
        CompoundOperationWrapper.createWithResult(selectedValidatorList)
    }

    func activeValidatorsOperation(for _: AccountAddress) -> CompoundOperationWrapper<[SelectedValidatorInfo]> {
        CompoundOperationWrapper.createWithResult(selectedValidatorList)
    }

    func pendingValidatorsOperation(for _: [AccountId]) -> CompoundOperationWrapper<[SelectedValidatorInfo]> {
        CompoundOperationWrapper.createWithResult(selectedValidatorList)
    }

    func wannabeValidatorsOperation(for _: [AccountId]) -> CompoundOperationWrapper<[SelectedValidatorInfo]> {
        CompoundOperationWrapper.createWithResult(selectedValidatorList)
    }

    func allPreferred(
        for _: PreferredValidatorsProviderModel?
    ) -> CompoundOperationWrapper<ElectedAndPrefValidators> {
        let electedAndPrefValidators = ElectedAndPrefValidators(
            allElectedValidators: electedValidatorList,
            notExcludedElectedValidators: electedValidatorList,
            preferredValidators: selectedValidatorList
        )

        return .createWithResult(electedAndPrefValidators)
    }
}
