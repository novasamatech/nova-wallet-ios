import Foundation

protocol SubtensorStakingSetupViewProtocol: ControllerBackedProtocol {
    func didReceiveAmount(inputViewModel: AmountInputViewModelProtocol)
    func didReceiveAmountAsset(viewModel: AssetBalanceViewModelProtocol)
    func didReceive(viewModel: SubtensorStakingSetupViewModel)
}

protocol SubtensorStakingSetupPresenterProtocol: AnyObject {
    func setup()
    func updateAmount(_ newValue: Decimal?)
    func selectMax()
    func selectAmountPercentage(_ percentage: Float)
    func selectValidator()
    func selectSlippage()
    func getTao()
    func proceed()
}

protocol SubtensorSetupInteractorInputProtocol: SubtensorStakingBaseInteractorInputProtocol {
    func presetValidator(on subnet: SubtensorSubnetRef, existingHotkey: AccountId?)
    func loadLockedValidator(_ hotkey: AccountId, on subnet: SubtensorSubnetRef)
    func loadRootYield()
    func loadSubnet(netuid: UInt16)
    func loadCatalogue()
    func saveSlippage(_ tolerance: BigRational)
}

protocol SubtensorSetupInteractorOutputProtocol: SubtensorStakingBaseInteractorOutputProtocol {
    func didReceiveValidator(_ validator: SubtensorValidatorDirectoryItem?, on subnet: SubtensorSubnetRef)
    func didReceiveRootYield(_ yield: SubtensorReportedYield?)
    func didReceiveSubnet(_ target: SubtensorStakeTarget)
    func didFailSubnet(_ error: Error)
    func didReceiveCatalogue(_ catalogue: SubtensorSubnetCatalogue?)
}

protocol SubtensorStakingSetupWireframeProtocol: AlertPresentable, ErrorPresentable, FeeRetryable,
    CommonRetryable, SubtensorStakingErrorPresentable, SubtensorGetTaoRouting {
    func showConfirmation(
        from view: SubtensorStakingSetupViewProtocol?,
        model: SubtensorStakingConfirmModel
    )

    func showValidatorSelection(
        from view: SubtensorStakingSetupViewProtocol?,
        target: SubtensorStakeTarget,
        selectedHotkey: AccountId?,
        delegate: SubtensorValidatorSelectDelegate
    )

    func showSubnetSelection(
        from view: SubtensorStakingSetupViewProtocol?,
        delegate: SubtensorSubnetSelectDelegate
    )

    func showSlippageEdit(
        from view: SubtensorStakingSetupViewProtocol?,
        current: BigRational,
        completion: @escaping (BigRational) -> Void
    )

    func popTopControllers(
        from view: SubtensorStakingSetupViewProtocol?,
        completion: @escaping () -> Void
    )
}
