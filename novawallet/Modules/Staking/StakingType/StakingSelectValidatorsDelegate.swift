protocol StakingSelectValidatorsDelegateProtocol: AnyObject {
    func changeValidatorsSelection(validatorList: [SelectedValidatorInfo], maxTargets: Int)
}
