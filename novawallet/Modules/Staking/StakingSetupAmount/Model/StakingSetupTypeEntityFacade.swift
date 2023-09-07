import Foundation

final class StakingSetupTypeEntityFacade {
    static var associationKey: String = "com.nova.wallet.setup.entity.flow"

    weak var delegate: StakingTypeDelegate?
    let selectedMethod: StakingSelectionMethod

    init(selectedMethod: StakingSelectionMethod, delegate: StakingTypeDelegate?) {
        self.selectedMethod = selectedMethod
        self.delegate = delegate
    }

    func bindToFlow(controller: AnyObject) {
        objc_setAssociatedObject(
            controller,
            &Self.associationKey,
            self,
            .OBJC_ASSOCIATION_RETAIN
        )
    }

    private func convert(validatorList: [SelectedValidatorInfo], maxTargets: Int) -> StakingSelectionMethod? {
        guard case let .direct(validators) = selectedMethod.selectedStakingOption,
              let restrictions = selectedMethod.restrictions else {
            return nil
        }

        let selectedAddresses = validatorList.map(\.address)

        let usedRecommendation = Set(selectedAddresses) == Set(validators.recommendedValidators.map(\.address))
        return .manual(.init(
            staking: .direct(.init(
                targets: validatorList,
                maxTargets: maxTargets,
                electedValidators: validators.electedValidators,
                recommendedValidators: validators.recommendedValidators
            )),
            restrictions: restrictions,
            usedRecommendation: usedRecommendation
        ))
    }
}

extension StakingSetupTypeEntityFacade: StakingSelectValidatorsDelegateProtocol {
    func changeValidatorsSelection(validatorList: [SelectedValidatorInfo], maxTargets: Int) {
        guard let method = convert(validatorList: validatorList, maxTargets: maxTargets) else {
            return
        }

        delegate?.changeStakingType(method: method)
    }
}

extension StakingSetupTypeEntityFacade: StakingSelectPoolDelegate {
    func changePoolSelection(selectedPool: NominationPools.SelectedPool, isRecommended: Bool) {
        guard let restrictions = selectedMethod.restrictions else {
            return
        }

        let method = StakingSelectionMethod.manual(.init(
            staking: .pool(selectedPool),
            restrictions: restrictions,
            usedRecommendation: isRecommended
        ))

        delegate?.changeStakingType(method: method)
    }
}
